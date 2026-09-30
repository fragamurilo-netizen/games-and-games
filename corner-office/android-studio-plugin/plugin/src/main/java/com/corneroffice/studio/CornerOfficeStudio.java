package com.corneroffice.studio;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.graphics.Color;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceRequest;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import java.util.Collections;
import java.util.Set;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

/** Hosts the original Canvas renderer inside the game screen.
 *  The WebView is a child of the activity layout, placed over the rectangle that
 *  FightReplayView reserves; Godot keeps drawing its own frame around it.
 *  The HTML contains all fonts, code, catalog and immutable replay; no network,
 *  Python server, external app, alternate anatomy or fight logic is involved. */
public final class CornerOfficeStudio extends GodotPlugin {
    private WebView web;
    private int x, y, w, h;
    public CornerOfficeStudio(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "CornerOfficeStudio"; }
    @Override public Set<SignalInfo> getPluginSignals() { return Collections.singleton(new SignalInfo("closed")); }

    /** Rectangle in window pixels, as computed by Godot from the reserved Control. */
    @UsedByGodot @SuppressLint("SetJavaScriptEnabled")
    public void show(String html, int left, int top, int width, int height) {
        runOnUiThread(() -> {
            dismiss(false);
            Activity activity = getActivity();
            if (activity == null) return;
            web = new WebView(activity);
            web.setBackgroundColor(Color.rgb(17, 20, 23));
            web.getSettings().setJavaScriptEnabled(true);
            web.getSettings().setAllowFileAccess(false);
            web.getSettings().setAllowContentAccess(false);
            web.getSettings().setBlockNetworkLoads(true);
            web.getSettings().setDomStorageEnabled(false);
            web.getSettings().setMediaPlaybackRequiresUserGesture(true);
            web.setOverScrollMode(View.OVER_SCROLL_NEVER);
            web.setWebViewClient(new WebViewClient() {
                @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) { return true; }
                @Override public boolean shouldOverrideUrlLoading(WebView view, String url) { return true; }
            });
            web.addJavascriptInterface(new Object() {
                @JavascriptInterface public void close() { CornerOfficeStudio.this.close(); }
            }, "CornerOffice");
            ViewGroup root = activity.findViewById(android.R.id.content);
            root.addView(web, params(left, top, width, height));
            web.loadDataWithBaseURL("https://corner-office.invalid/", html, "text/html", "UTF-8", null);
        });
    }
    @UsedByGodot public void set_rect(int left, int top, int width, int height) {
        runOnUiThread(() -> { if (web != null) web.setLayoutParams(params(left, top, width, height)); });
    }
    @UsedByGodot public void set_visible(boolean visible) {
        runOnUiThread(() -> { if (web != null) web.setVisibility(visible ? View.VISIBLE : View.GONE); });
    }
    @UsedByGodot public void close() { runOnUiThread(() -> dismiss(true)); }
    private FrameLayout.LayoutParams params(int left, int top, int width, int height) {
        x = left; y = top; w = Math.max(1, width); h = Math.max(1, height);
        FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(w, h);
        p.leftMargin = x; p.topMargin = y;
        return p;
    }
    private void dismiss(boolean notify) {
        boolean wasOpen = web != null;
        if (web != null) {
            web.stopLoading();
            web.removeJavascriptInterface("CornerOffice");
            if (web.getParent() instanceof ViewGroup) ((ViewGroup) web.getParent()).removeView(web);
            web.destroy();
            web = null;
        }
        if (notify && wasOpen) emitSignal("closed");
    }
    @Override public boolean onMainBackPressed() { if (web == null) return false; close(); return true; }
    @Override public void onMainPause() { runOnUiThread(() -> { if (web != null) { web.evaluateJavascript("window.pauseCornerOffice && window.pauseCornerOffice()", null); web.onPause(); } }); }
    @Override public void onMainResume() { runOnUiThread(() -> { if (web != null) web.onResume(); }); }
    @Override public void onMainDestroy() { runOnUiThread(() -> dismiss(false)); }
}
