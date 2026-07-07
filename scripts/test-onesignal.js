const { sendPushToUsers } = require('./onesignal');

const userId = process.env.TEST_ONESIGNAL_USER_ID;
const title = process.env.TEST_ONESIGNAL_TITLE || 'اختبار إشعارات ZaWolf';
const body =
  process.env.TEST_ONESIGNAL_BODY ||
  'هذا إشعار اختبار للتأكد من أن OneSignal يعمل بشكل صحيح.';

if (!userId) {
  console.error('Missing TEST_ONESIGNAL_USER_ID. Use the Firebase user id of a user who logged in once.');
  process.exit(1);
}

sendPushToUsers([userId], title, body, {
  type: 'onesignal_test',
  source: 'github_actions',
})
  .then((result) => {
    console.log('OneSignal test result:', JSON.stringify(result, null, 2));
  })
  .catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
