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
import java.util.Arrays;
import java.util.HashSet;
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
    /** Invisible WebView that draws fighter portraits with the same Fight Studio code. */
    private WebView sheet;
    private int x, y, w, h;
    public CornerOfficeStudio(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "CornerOfficeStudio"; }
    @Override public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(new SignalInfo("closed"), new SignalInfo("next"),
                new SignalInfo("portrait", String.class, String.class), new SignalInfo("portraits_done")));
    }

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
                /** Whole-night playback: Godot owns the card queue and loads the next bout. */
                @JavascriptInterface public void next() { runOnRenderThread(() -> emitSignal("next")); }
            }, "CornerOffice");
            ViewGroup root = activity.findViewById(android.R.id.content);
            root.addView(web, params(left, top, width, height));
            web.loadDataWithBaseURL("https://corner-office.invalid/", html, "text/html", "UTF-8", null);
        });
    }
    /** Renders a portrait sheet (PortraitService) off screen. Each PNG comes back
     *  as a data URL through the "portrait" signal, then "portraits_done". */
    @UsedByGodot @SuppressLint("SetJavaScriptEnabled")
    public void render_portraits(String html) {
        runOnUiThread(() -> {
            dismissSheet();
            Activity activity = getActivity();
            if (activity == null) { runOnRenderThread(() -> emitSignal("portraits_done")); return; }
            sheet = new WebView(activity);
            sheet.getSettings().setJavaScriptEnabled(true);
            sheet.getSettings().setAllowFileAccess(false);
            sheet.getSettings().setAllowContentAccess(false);
            sheet.getSettings().setBlockNetworkLoads(true);
            sheet.setAlpha(0f);
            sheet.setWebViewClient(new WebViewClient() {
                @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) { return true; }
                @Override public boolean shouldOverrideUrlLoading(WebView view, String url) { return true; }
            });
            sheet.addJavascriptInterface(new Object() {
                @JavascriptInterface public void portrait(String key, String png) { runOnRenderThread(() -> emitSignal("portrait", key, png)); }
                @JavascriptInterface public void portraitsDone() {
                    runOnRenderThread(() -> emitSignal("portraits_done"));
                    runOnUiThread(CornerOfficeStudio.this::dismissSheet);
                }
            }, "CornerOffice");
            ViewGroup root = activity.findViewById(android.R.id.content);
            FrameLayout.LayoutParams p = new FrameLayout.LayoutParams(1, 1);
            root.addView(sheet, p);
            sheet.loadDataWithBaseURL("https://corner-office.invalid/", html, "text/html", "UTF-8", null);
        });
    }
    private void dismissSheet() {
        if (sheet == null) return;
        sheet.stopLoading();
        sheet.removeJavascriptInterface("CornerOffice");
        if (sheet.getParent() instanceof ViewGroup) ((ViewGroup) sheet.getParent()).removeView(sheet);
        sheet.destroy();
        sheet = null;
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
    @Override public void onMainDestroy() { runOnUiThread(() -> { dismiss(false); dismissSheet(); }); }
}
