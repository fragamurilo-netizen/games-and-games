package com.corneroffice.studio;

import android.app.Dialog;
import android.annotation.SuppressLint;
import android.graphics.Color;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebResourceRequest;
import android.view.WindowManager;
import java.util.Collections;
import java.util.Set;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

/** Hosts the original Canvas renderer as an offline Android surface.
 *  The HTML contains all fonts, code, catalog and immutable replay; no network,
 *  Python server, external app, alternate anatomy or fight logic is involved. */
public final class CornerOfficeStudio extends GodotPlugin {
    private Dialog dialog;
    private WebView web;
    public CornerOfficeStudio(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "CornerOfficeStudio"; }
    @Override public Set<SignalInfo> getPluginSignals() { return Collections.singleton(new SignalInfo("closed")); }

    @UsedByGodot @SuppressLint("SetJavaScriptEnabled")
    public void show(String html) {
        runOnUiThread(() -> {
            dismiss(false);
            if (getActivity() == null) return;
            web = new WebView(getActivity());
            web.setBackgroundColor(Color.rgb(17, 20, 23));
            web.getSettings().setJavaScriptEnabled(true);
            web.getSettings().setAllowFileAccess(false);
            web.getSettings().setAllowContentAccess(false);
            web.getSettings().setBlockNetworkLoads(true);
            web.getSettings().setDomStorageEnabled(false);
            web.setWebViewClient(new WebViewClient() {
                @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) { return true; }
                @Override public boolean shouldOverrideUrlLoading(WebView view, String url) { return true; }
            });
            web.addJavascriptInterface(new Object() {
                @JavascriptInterface public void close() { CornerOfficeStudio.this.close(); }
            }, "CornerOffice");
            dialog = new Dialog(getActivity(), android.R.style.Theme_Black_NoTitleBar_Fullscreen);
            dialog.setContentView(web);
            dialog.setOnCancelListener(ignored -> dismiss(true));
            dialog.show();
            if (dialog.getWindow() != null) dialog.getWindow().setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT);
            web.loadDataWithBaseURL("https://corner-office.invalid/", html, "text/html", "UTF-8", null);
        });
    }
    @UsedByGodot public void close() { runOnUiThread(() -> dismiss(true)); }
    private void dismiss(boolean notify) {
        boolean wasOpen = dialog != null;
        if (dialog != null) { dialog.setOnCancelListener(null); dialog.dismiss(); dialog = null; }
        if (web != null) { web.stopLoading(); web.removeJavascriptInterface("CornerOffice"); web.destroy(); web = null; }
        if (notify && wasOpen) emitSignal("closed");
    }
    @Override public boolean onMainBackPressed() { if (dialog == null) return false; close(); return true; }
    @Override public void onMainPause() { runOnUiThread(() -> { if (web != null) { web.evaluateJavascript("window.pauseCornerOffice && window.pauseCornerOffice()", null); web.onPause(); } }); }
    @Override public void onMainResume() { runOnUiThread(() -> { if (web != null) web.onResume(); }); }
    @Override public void onMainDestroy() { runOnUiThread(() -> dismiss(false)); }
}
