// SPDX-License-Identifier: LicenseRef-AGPL-3.0-only-OpenSSL

package com.metallic.chiaki.regist

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import android.view.Gravity
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.metallic.chiaki.R
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * Lets the user sign in on Sony's own PlayStation Network page and returns their
 * Account ID, so they never have to look it up and type it by hand.
 * The password is typed on Sony's page only; this app receives a one-time code.
 */
class PsnLoginActivity: AppCompatActivity()
{
	companion object
	{
		const val EXTRA_ACCOUNT_ID = "psn_account_id"

		private const val CLIENT_ID = "ba495a24-818c-472b-b12d-ff231c1b5745"
		private const val CLIENT_SECRET = "mvaiZkRsAsI1IBkY"
		private const val REDIRECT_URI = "https://remoteplay.dl.playstation.net/remoteplay/redirect"
		private const val TOKEN_URL = "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/token"
		private const val LOGIN_URL = "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/authorize" +
				"?service_entity=urn:service-entity:psn&response_type=code&client_id=$CLIENT_ID" +
				"&redirect_uri=$REDIRECT_URI&scope=psn:clientapp&request_locale=en_US&ui=pr" +
				"&service_logo=ps&layout_type=popup&smcid=remoteplay&prompt=always&PlatformPrivacyWs1=minimal&"
	}

	private lateinit var webView: WebView
	private lateinit var progressBar: ProgressBar
	private var handled = false

	@SuppressLint("SetJavaScriptEnabled")
	override fun onCreate(savedInstanceState: Bundle?)
	{
		super.onCreate(savedInstanceState)
		title = getString(R.string.regist_psn_login_title)

		val root = FrameLayout(this)
		webView = WebView(this)
		progressBar = ProgressBar(this)
		progressBar.visibility = View.GONE
		root.addView(webView, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
		root.addView(progressBar, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER))
		setContentView(root)

		CookieManager.getInstance().setAcceptCookie(true)
		webView.settings.javaScriptEnabled = true
		webView.settings.domStorageEnabled = true
		webView.webViewClient = object: WebViewClient()
		{
			override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean
				= handleUrl(request.url.toString())

			override fun onPageStarted(view: WebView, url: String, favicon: android.graphics.Bitmap?)
			{
				handleUrl(url)
			}
		}
		webView.loadUrl(LOGIN_URL)
	}

	override fun onDestroy()
	{
		webView.destroy()
		super.onDestroy()
	}

	private fun handleUrl(url: String): Boolean
	{
		if(!url.startsWith(REDIRECT_URI))
			return false
		if(handled)
			return true
		handled = true
		val code = Uri.parse(url).getQueryParameter("code")
		if(code.isNullOrEmpty())
		{
			fail()
			return true
		}
		webView.stopLoading()
		webView.visibility = View.INVISIBLE
		progressBar.visibility = View.VISIBLE
		thread {
			val accountId = try { fetchAccountId(code) } catch(e: Exception) { null }
			runOnUiThread {
				if(accountId == null)
					fail()
				else
				{
					setResult(Activity.RESULT_OK, Intent().putExtra(EXTRA_ACCOUNT_ID, accountId))
					finish()
				}
			}
		}
		return true
	}

	private fun fail()
	{
		Toast.makeText(this, R.string.regist_psn_login_failed, Toast.LENGTH_LONG).show()
		setResult(Activity.RESULT_CANCELED)
		finish()
	}

	private fun basicAuth(): String
		= "Basic " + Base64.encodeToString("$CLIENT_ID:$CLIENT_SECRET".toByteArray(Charsets.US_ASCII), Base64.NO_WRAP)

	private fun readBody(connection: HttpURLConnection): String
	{
		if(connection.responseCode != 200)
			throw IllegalStateException("HTTP " + connection.responseCode)
		return connection.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
	}

	/** Exchanges the one-time code for the account's numeric id and encodes it the way registration expects. */
	private fun fetchAccountId(code: String): String
	{
		val tokenConnection = URL(TOKEN_URL).openConnection() as HttpURLConnection
		val token = try
		{
			tokenConnection.requestMethod = "POST"
			tokenConnection.doOutput = true
			tokenConnection.connectTimeout = 15000
			tokenConnection.readTimeout = 15000
			tokenConnection.setRequestProperty("Authorization", basicAuth())
			tokenConnection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
			val body = "grant_type=authorization_code&code=" + URLEncoder.encode(code, "UTF-8") + "&redirect_uri=$REDIRECT_URI&"
			tokenConnection.outputStream.use { it.write(body.toByteArray(Charsets.US_ASCII)) }
			JSONObject(readBody(tokenConnection)).getString("access_token")
		}
		finally
		{
			tokenConnection.disconnect()
		}

		val infoConnection = URL(TOKEN_URL + "/" + URLEncoder.encode(token, "UTF-8")).openConnection() as HttpURLConnection
		val userId = try
		{
			infoConnection.connectTimeout = 15000
			infoConnection.readTimeout = 15000
			infoConnection.setRequestProperty("Authorization", basicAuth())
			JSONObject(readBody(infoConnection)).getString("user_id")
		}
		finally
		{
			infoConnection.disconnect()
		}

		val bytes = ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putLong(userId.toULong().toLong()).array()
		return Base64.encodeToString(bytes, Base64.NO_WRAP)
	}
}
