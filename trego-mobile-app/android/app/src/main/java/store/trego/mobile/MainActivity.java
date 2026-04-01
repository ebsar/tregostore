package store.trego.mobile;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.os.Build;
import android.os.Bundle;

import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    public static final String CHANNEL_ORDERS = "trego_orders";
    public static final String CHANNEL_MESSAGES = "trego_messages";
    public static final String CHANNEL_UPDATES = "trego_updates";

    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        createNotificationChannels();
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
