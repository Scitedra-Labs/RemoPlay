// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

#ifndef REMOPLAY_UPDATER_H
#define REMOPLAY_UPDATER_H

#include <QObject>
#include <QString>

class QNetworkAccessManager;
class QNetworkReply;
class QFile;

// In-app updater: looks at the "latest" GitHub release, downloads the installer
// for this platform, installs it without questions and starts the app again.
class Updater : public QObject
{
	Q_OBJECT

	public:
		explicit Updater(QObject *parent = nullptr);

		void Check();
		void Install();

	signals:
		void Available();
		void Progress(int percent);
		void Failed(const QString &reason);
		// the installer has been started, the app has to quit now
		void QuitRequested();

	private:
		bool RunInstaller(const QString &path);

		QNetworkAccessManager *network;
		QNetworkReply *download = nullptr;
		QFile *download_file = nullptr;
		bool busy = false;
};

#endif // REMOPLAY_UPDATER_H
