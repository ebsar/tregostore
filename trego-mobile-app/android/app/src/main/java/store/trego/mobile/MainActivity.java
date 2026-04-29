package store.trego.mobile;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.webkit.WebSettings;
import android.webkit.WebView;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    public static final String CHANNEL_ORDERS = "trego_orders";
    public static final String CHANNEL_MESSAGES = "trego_messages";
    public static final String CHANNEL_UPDATES = "trego_updates";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        applyTregoChrome();
        tuneWebView();
        createNotificationChannels();
    }

    private void applyTregoChrome() {
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.WHITE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            int flags = View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                flags |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
            }
            getWindow().getDecorView().setSystemUiVisibility(flags);
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            getWindow().setNavigationBarDividerColor(Color.TRANSPARENT);
        }
    }

    private void tuneWebView() {
        if (getBridge() == null || getBridge().getWebView() == null) {
            return;
        }

        WebView webView = getBridge().getWebView();
        webView.setBackgroundColor(Color.rgb(246, 247, 248));

        WebSettings settings = webView.getSettings();
        settings.setTextZoom(100);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            settings.setOffscreenPreRaster(true);
        }
    }

    private void createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return;
        }

        NotificationManager manager = getSystemService(NotificationManager.class);
        if (manager == null) {
            return;
        }

        NotificationChannel ordersChannel = new NotificationChannel(
            CHANNEL_ORDERS,
            getString(R.string.notification_channel_orders_name),
            NotificationManager.IMPORTANCE_HIGH
        );
        ordersChannel.setDescription(getString(R.string.notification_channel_orders_description));
        ordersChannel.enableVibration(true);
        ordersChannel.setShowBadge(true);

        NotificationChannel messagesChannel = new NotificationChannel(
            CHANNEL_MESSAGES,
            getString(R.string.notification_channel_messages_name),
            NotificationManager.IMPORTANCE_HIGH
        );
        messagesChannel.setDescription(getString(R.string.notification_channel_messages_description));
        messagesChannel.enableVibration(true);
        messagesChannel.setShowBadge(true);

        NotificationChannel updatesChannel = new NotificationChannel(
            CHANNEL_UPDATES,
            getString(R.string.notification_channel_updates_name),
            NotificationManager.IMPORTANCE_DEFAULT
        );
        updatesChannel.setDescription(getString(R.string.notification_channel_updates_description));
        updatesChannel.enableVibration(true);
        updatesChannel.setShowBadge(true);

        manager.createNotificationChannel(ordersChannel);
        manager.createNotificationChannel(messagesChannel);
        manager.createNotificationChannel(updatesChannel);
    }
}
