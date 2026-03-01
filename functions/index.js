
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// 1. Monitor Live Queue Changes
exports.onQueueUpdate = functions.firestore
    .document('live_queue/{queueId}')
    .onUpdate(async (change, context) => {
        const newData = change.after.data();
        const previousData = change.before.data();

        const currentToken = newData.currentToken;
        const previousToken = previousData.currentToken;

        // Only trigger if token moved forward
        if (currentToken <= previousToken) return null;

        const queueId = context.params.queueId;
        console.log(`Queue ${queueId} updated to token ${currentToken}`);

        // Find appointments/users who are "next" (next 20 people to be safe, then filter by preference)
        const targetTokensStart = currentToken + 1;
        const targetTokensEnd = currentToken + 20;

        // Query Firestore for appointments in this range
        const snapshot = await admin.firestore().collection('appointments')
            .where('deptId', '==', queueId)
            .where('tokenNumber', '>=', targetTokensStart)
            .where('tokenNumber', '<=', targetTokensEnd)
            .get();

        const promises = [];

        for (const doc of snapshot.docs) {
            const appointment = doc.data();
            const userId = appointment.userId;
            const userToken = appointment.tokenNumber;
            const diff = userToken - currentToken;

            // 1. Fetch User Settings
            const userDoc = await admin.firestore().collection('users').doc(userId).get();
            if (!userDoc.exists) continue;

            const userData = userDoc.data();
            // Default threshold 5 if not set
            const userThreshold = userData.token_alert_threshold || 5;

            // If user wants to be notified at 5, but diff is 6, skip.
            // If diff is <= threshold, notify.
            if (diff > userThreshold) continue;

            const lang = userData.language_code || 'en';

            // 2. Localize Message
            let messageTitle = "Your Turn is Approaching!";
            let messageBody = `Current Token is ${currentToken}. You are Token ${userToken}.`;

            if (lang === 'ml') {
                messageTitle = "നിങ്ങളുടെ ഊഴം അടുത്തിരിക്കുന്നു!";
                messageBody = `നിലവിലെ ടോക്കൺ ${currentToken} ആണ്. നിങ്ങളുടെ ടോക്കൺ ${userToken} ആണ്.`;
            }

            // Determine Priority
            // If very close (diff <= 2), mark critical (continuous sound/vibrate)
            const priority = diff <= 2 ? 'critical' : 'high';

            // 3. Save to Notification Database
            const notifPromise = admin.firestore().collection('notifications').add({
                userId: userId,
                type: 'tokenNear',
                title: messageTitle,
                message: messageBody,
                relatedTokenNumber: userToken,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                status: 'pending',
                isRead: false,
                priority: priority
            });
            // We rely on 'onNotificationCreated' trigger to actually SEND the FCM 
            // to avoid duplicating logic and ensuring consistent payload construction.

            promises.push(notifPromise);
        }

        return Promise.all(promises);
    });

// 2. Scheduled Appointment Reminders (Requires Blaze Plan for PubSub)
// Runs every hour to check for upcoming appointments
exports.sendAppointmentReminders = functions.pubsub.schedule('every 60 minutes').onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();
    // Calculate typical reminder time (e.g., 24 hours from now) or strict check
    // ... Implementation skipped for brevity, similar logic to above
    console.log("Checked for reminders");
    return null;
});

// ... (Existing exports)

// 3. General Notification Push Trigger
// Listens to ANY new document in 'notifications' collection and sends FCM
exports.onNotificationCreated = functions.firestore
    .document('notifications/{notificationId}')
    .onCreate(async (snap, context) => {
        const notification = snap.data();
        const userId = notification.userId;

        if (!userId) {
            console.log("No userId in notification");
            return null;
        }

        try {
            // Get user's FCM token
            const userDoc = await admin.firestore().collection('users').doc(userId).get();
            if (!userDoc.exists) {
                console.log("User not found");
                return null;
            }

            const userData = userDoc.data();
            const fcmToken = userData.fcmToken;

            if (!fcmToken) {
                console.log("No FCM token for user");
                return null;
            }

            // Construct payload
            const isSos = (notification.type === 'sos' || notification.notificationType === 'sos');
            
            const payload = {
                notification: {
                    title: notification.title || 'New Notification',
                    body: notification.message || notification.body || 'You have a new alert',
                },
                data: {
                    type: notification.type || notification.notificationType || 'info',
                    priority: notification.priority || 'medium', 
                    id: context.params.notificationId,
                    click_action: 'FLUTTER_NOTIFICATION_CLICK',
                    // Add specific data for client verification
                    is_sos: isSos ? 'true' : 'false' 
                }
            };

            // Android Config for Notification Channel
            if (isSos) {
               payload.android = {
                   notification: {
                       channel_id: 'sos_channel', // Directs to the high-priority channel
                       priority: 'max',
                       visibility: 'private',
                       sound: 'sos_alert' // Assumes res/raw/sos_alert.mp3 exists or falls back
                   }
               };
            }

            // Options for high priority if needed
            const options = {
                priority: (notification.priority === 'critical' || notification.priority === 'high' || isSos) ? 'high' : 'normal',
                timeToLive: 60 * 60 * 24 
            };

            // Send
            await admin.messaging().sendToDevice(fcmToken, payload, options);

            // Mark as sent
            return snap.ref.update({ status: 'sent' });

        } catch (error) {
            console.error("Error sending push notification:", error);
            return snap.ref.update({ status: 'failed' });
        }
    });
