// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

package com.metallic.chiaki.common

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import android.util.Log
import android.widget.Toast
import com.google.android.material.dialog.MaterialAlertDialogBuilder
import com.metallic.chiaki.R
import com.metallic.chiaki.main.MainActivity
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * In-app updates: looks at the "latest" GitHub release, downloads the newer APK
 * and hands it to the system installer from inside the app.
 */
object UpdateManager
{
	private const val TAG = "UpdateManager"
	private const val BASE_URL = "https://github.com/Scitedra-Labs/RemoPlay/releases/latest/download/"
	const val ACTION_INSTALL_STATUS = "com.metallic.chiaki.UPDATE_INSTALL_STATUS"

	// builds from the cloud use the commit time as version code, anything small is a developer build
	private const val MIN_CLOUD_VERSION_CODE = 1_000_000L

	private var checked = false

	fun checkForUpdate(activity: Activity)
	{
		if(checked)
			return
		checked = true
		val current = currentVersionCode(activity)
		if(current < MIN_CLOUD_VERSION_CODE)
			return
		Thread {
			val remote = try { fetchRemoteBuild() } catch(e: Exception) { Log.i(TAG, "Update check failed: $e"); return@Thread }
			if(remote <= current)
				return@Thread
			activity.runOnUiThread {
				if(activity.isFinishing || activity.isDestroyed)
					return@runOnUiThread
				MaterialAlertDialogBuilder(activity)
					.setTitle(R.string.update_title)
					.setMessage(R.string.update_message)
					.setPositiveButton(R.string.update_now) { _, _ -> downloadAndInstall(activity) }
					.setNegativeButton(R.string.update_later, null)
					.show()
			}
		}.start()
	}

	private fun currentVersionCode(context: Context): Long
	{
		val info = context.packageManager.getPackageInfo(context.packageName, 0)
		return if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
	}

	private fun open(name: String): HttpURLConnection
	{
		val connection = URL(BASE_URL + name).openConnection() as HttpURLConnection
		connection.connectTimeout = 15000
		connection.readTimeout = 30000
		connection.instanceFollowRedirects = true
		return connection
	}

	private fun fetchRemoteBuild(): Long
	{
		val connection = open("version-android.json")
		try
		{
			val text = connection.inputStream.bufferedReader().use { it.readText() }
			return JSONObject(text).getLong("build")
		}
		finally
		{
			connection.disconnect()
		}
	}

	private fun downloadAndInstall(activity: Activity)
	{
		val context = activity.applicationContext
		Toast.makeText(context, R.string.update_downloading, Toast.LENGTH_LONG).show()
		Thread {
			try
			{
				val file = File(context.cacheDir, "remoplay-update.apk")
				val connection = open("RemoPlay-Android.apk")
				try
				{
					connection.inputStream.use { input -> file.outputStream().use { output -> input.copyTo(output) } }
				}
				finally
				{
					connection.disconnect()
				}
				install(context, file)
			}
			catch(e: Exception)
			{
				Log.e(TAG, "Update failed", e)
				activity.runOnUiThread { Toast.makeText(context, R.string.update_failed, Toast.LENGTH_LONG).show() }
			}
		}.start()
	}

	private fun install(context: Context, file: File)
	{
		val installer = context.packageManager.packageInstaller
		val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
		params.setAppPackageName(context.packageName)
		// Android 12+: an app may update itself without the system asking the user again
		if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
			params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
		val sessionId = installer.createSession(params)
		installer.openSession(sessionId).use { session ->
			session.openWrite("base.apk", 0, file.length()).use { output ->
				file.inputStream().use { it.copyTo(output) }
				session.fsync(output)
			}
			val intent = Intent(context, UpdateReceiver::class.java).setAction(ACTION_INSTALL_STATUS)
			val flags = PendingIntent.FLAG_UPDATE_CURRENT or
					(if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0)
			session.commit(PendingIntent.getBroadcast(context, sessionId, intent, flags).intentSender)
		}
	}
}

class UpdateReceiver: BroadcastReceiver()
{
	override fun onReceive(context: Context, intent: Intent)
	{
		when(intent.action)
		{
			UpdateManager.ACTION_INSTALL_STATUS -> when(intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE))
			{
				PackageInstaller.STATUS_PENDING_USER_ACTION ->
				{
					// the system wants one confirmation from the user (older Android, or the very first update)
					@Suppress("DEPRECATION")
					val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT) ?: return
					confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
					try { context.startActivity(confirm) } catch(e: Exception) { Log.e("UpdateReceiver", "Can't show install confirmation", e) }
				}
				PackageInstaller.STATUS_SUCCESS -> {}
				else ->
				{
					Log.e("UpdateReceiver", "Install failed: " + intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE))
					Toast.makeText(context, R.string.update_failed, Toast.LENGTH_LONG).show()
				}
			}
			Intent.ACTION_MY_PACKAGE_REPLACED ->
			{
				// the new version is installed, try to open it again (Android may not allow this from the background)
				try
				{
					context.startActivity(Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
				}
				catch(e: Exception)
				{
					Log.i("UpdateReceiver", "Can't reopen after update: $e")
				}
			}
		}
	}
}
