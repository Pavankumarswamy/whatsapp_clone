const {onValueCreated} = require('firebase-functions/v2/database');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendChatNotification = onValueCreated(
  {
    ref: '/chats/{chatId}/messages/{messageId}',
    instance: 'whatsup-519-default-rtdb',
  },
  async (event) => {
    const message = event.data.val();
    const chatId = event.params.chatId;
    const senderId = message.sender;
    const recipientId = chatId.replace(senderId, '').replace('_', '');

    // Fetch sender's data from users node
    const senderRef = admin.database().ref(`/users/${senderId}`);
    const senderSnapshot = await senderRef.once('value');
    const senderData = senderSnapshot.val();
    const senderEmail = senderData?.email || senderId;
    const senderDisplay = senderEmail.replace('@gmail.com', '');

    const payload = {
      notification: {
        title: `New Message from ${senderDisplay}`,
        body: message.text || 'Image',
      },
      data: {
        chatId: chatId,
      },
      topic: `user_${recipientId}`,
    };

    logger.info('Sending notification to:', {recipientId});
    return admin.messaging().send(payload);
  },
);
