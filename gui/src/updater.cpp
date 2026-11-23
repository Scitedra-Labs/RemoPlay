// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#include "updater.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QStandardPaths>
#include <QUrl>

// Set by the cloud build to the time of the commit it was built from.
// 0 means a local/developer build, which never updates itself.
#ifndef REMOPLAY_BUILD_ID
#define REMOPLAY_BUILD_ID 0
#endif

#define UPDATE_BASE_URL "https://github.com/Scitedra-Labs/RemoPlay/releases/latest/download/"

#if defined(Q_OS_WIN)
#define UPDATE_VERSION_FILE "version-windows.json"
#define UPDATE_ASSET_FILE "RemoPlay-Windows-Setup.exe"
#elif defined(Q_OS_MACOS)
#define UPDATE_VERSION_FILE "version-macos.json"
#define UPDATE_ASSET_FILE "RemoPlay-macOS.dmg"
#endif

Updater::Updater(QObject *parent)
	: QObject(parent)
	, network(new QNetworkAccessManager(this))
{
}

void Updater::Check()
{
#ifdef UPDATE_VERSION_FILE
	const qint64 own_build = REMOPLAY_BUILD_ID;
	if(own_build <= 0 || busy)
		return;
	QNetworkRequest request(QUrl(QStringLiteral(UPDATE_BASE_URL UPDATE_VERSION_FILE)));
	request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
	request.setTransferTimeout(15000);
	QNetworkReply *reply = network->get(request);
	connect(reply, &QNetworkReply::finished, this, [this, reply, own_build]() {
		reply->deleteLater();
		if(reply->error() != QNetworkReply::NoError)
			return; // offline or nothing published yet, just try again on the next start
		const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
		const qint64 remote_build = obj.value(QStringLiteral("build")).toVariant().toLongLong();
		if(remote_build > own_build)
			emit Available();
	});
#endif
}

void Updater::Install()
{
#ifdef UPDATE_ASSET_FILE
	if(busy)
		return;
	const QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
	const QString path = QDir(dir).filePath(QStringLiteral(UPDATE_ASSET_FILE));
	QFile::remove(path);
	download_file = new QFile(path, this);
	if(!download_file->open(QIODevice::WriteOnly))
	{
		download_file->deleteLater();
		download_file = nullptr;
		emit Failed(tr("Could not save the update file"));
		return;
	}
	busy = true;
	QNetworkRequest request(QUrl(QStringLiteral(UPDATE_BASE_URL UPDATE_ASSET_FILE)));
	request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
	download = network->get(request);
	connect(download, &QNetworkReply::readyRead, this, [this]() {
		if(download_file)
			download_file->write(download->readAll());
	});
	connect(download, &QNetworkReply::downloadProgress, this, [this](qint64 received, qint64 total) {
		if(total > 0)
			emit Progress((int)(received * 100 / total));
	});
	connect(download, &QNetworkReply::finished, this, [this, path]() {
		download_file->write(download->readAll());
		const qint64 size = download_file->size();
		download_file->close();
		download_file->deleteLater();
		download_file = nullptr;
		const bool ok = download->error() == QNetworkReply::NoError && size > 1024 * 1024;
		download->deleteLater();
		download = nullptr;
		busy = false;
		if(!ok)
		{
			QFile::remove(path);
			emit Failed(tr("Downloading the update failed"));
			return;
		}
		if(RunInstaller(path))
			emit QuitRequested();
		else
			emit Failed(tr("Could not start the update"));
	});
#else
	emit Failed(tr("Updates are not available on this system"));
#endif
}

bool Updater::RunInstaller(const QString &path)
{
#if defined(Q_OS_WIN)
	// Inno Setup: install without any window, then start the app again (see scripts/chiaki-ng.iss)
	return QProcess::startDetached(path, {
		QStringLiteral("/VERYSILENT"),
		QStringLiteral("/SUPPRESSMSGBOXES"),
		QStringLiteral("/NORESTART"),
		QStringLiteral("/RELAUNCH=1")});
#elif defined(Q_OS_MACOS)
	// <something>/RemoPlay.app/Contents/MacOS => <something>/RemoPlay.app
	QDir bundle(QCoreApplication::applicationDirPath());
	if(!bundle.cdUp() || !bundle.cdUp() || !bundle.absolutePath().endsWith(QStringLiteral(".app")))
		return false;
	const QString app_path = bundle.absolutePath();
	// The app can only replace itself when it sits in a normal folder the user may write to.
	// Started straight from the disk image or from the Downloads quarantine it can't.
	if(app_path.startsWith(QStringLiteral("/Volumes/")) || app_path.contains(QStringLiteral("/AppTranslocation/"))
		|| !QFileInfo(QFileInfo(app_path).absolutePath()).isWritable())
		return false;

	const QString script_path = QDir(QStandardPaths::writableLocation(QStandardPaths::TempLocation)).filePath(QStringLiteral("remoplay-update.sh"));
	QFile script(script_path);
	if(!script.open(QIODevice::WriteOnly | QIODevice::Truncate))
		return false;
	script.write(
		"#!/bin/sh\n"
		"APP_PID=\"$1\"\n"
		"DMG=\"$2\"\n"
		"APP=\"$3\"\n"
		"# wait until the running app has quit\n"
		"while kill -0 \"$APP_PID\" 2>/dev/null; do sleep 0.3; done\n"
		"MNT=$(mktemp -d /tmp/remoplay-update.XXXXXX) || exit 1\n"
		"if hdiutil attach \"$DMG\" -nobrowse -noautoopen -mountpoint \"$MNT\" >/dev/null; then\n"
		"  SRC=$(ls -d \"$MNT\"/*.app 2>/dev/null | head -1)\n"
		"  if [ -d \"$SRC\" ]; then\n"
		"    rm -rf \"$APP.old\"\n"
		"    if mv \"$APP\" \"$APP.old\"; then\n"
		"      if ditto \"$SRC\" \"$APP\"; then\n"
		"        rm -rf \"$APP.old\"\n"
		"      else\n"
		"        # copying failed, put the previous version back\n"
		"        rm -rf \"$APP\"\n"
		"        mv \"$APP.old\" \"$APP\"\n"
		"      fi\n"
		"    fi\n"
		"    xattr -dr com.apple.quarantine \"$APP\" 2>/dev/null\n"
		"  fi\n"
		"  hdiutil detach \"$MNT\" -force >/dev/null\n"
		"fi\n"
		"rmdir \"$MNT\" 2>/dev/null\n"
		"rm -f \"$DMG\"\n"
		"open \"$APP\"\n");
	script.close();
	return QProcess::startDetached(QStringLiteral("/bin/sh"), {
		script_path,
		QString::number(QCoreApplication::applicationPid()),
		path,
		app_path});
#else
	Q_UNUSED(path);
	return false;
#endif
}
