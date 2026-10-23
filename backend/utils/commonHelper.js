/**
 * Shared utility functions used across backend controllers
 */

/**
 * 1. Cleanly extracts the last 10 digits from any phone input format (+91, spaces, dashes)
 * @param {string|number} phone
 * @returns {string} 10-digit phone number
 */
function sanitizePhone(phone) {
  if (!phone) return '';
  return phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
}

/**
 * 2. Generates a secure 4-digit OTP and its expiration timestamp
 * @param {number} validityMinutes default 5 minutes
 * @returns {{ otp: string, otpExpires: Date }}
 */
function generateOtp(validityMinutes = 5) {
  const otp = Math.floor(1000 + Math.random() * 9000).toString();
  const otpExpires = new Date(Date.now() + validityMinutes * 60 * 1000);
  return { otp, otpExpires };
}

/**
 * 3. Standardized date formatting for transaction subtitles and notifications (e.g. 'Oct 23 · 03:45 PM')
 * @param {Date} [date]
 * @returns {string}
 */
function formatTransactionDate(date = new Date()) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const d = date instanceof Date ? date : new Date(date);
  return `${months[d.getMonth()]} ${d.getDate()} · ${d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
}

module.exports = {
  sanitizePhone,
  generateOtp,
  formatTransactionDate,
};
