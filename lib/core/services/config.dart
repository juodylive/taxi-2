class Config {
static const googleKey = "YOUR_GOOGLE_MAPS_API_KEY_HERE";
  static const String oneSiginalAppid = 'YOUR_ONESIGNAL_APP_ID_HERE';
  static const String oneSiginalApiKey = 'YOUR_ONESIGNAL_API_KEY_HERE';


// Temporary base domain URL for setup (please add your final URL here)
 static const String baseDomain = 'https://rideon.unibooker.app';
  // Do not change any code below this line. ==================================================
  static const String version = '/api/v1/';
  static const String bearerVersion = '/api/';
  static const String baseUrl = '$baseDomain$version';
  static const String baseUrlForBearer = '$baseDomain$bearerVersion';
  static const String secretKey = '49382716504938271650493827165049';
  static const String generateToken = 'generateToken';
  static const String registerUser = 'userRegister';
  static const String socialLogin = 'socialLogin';
  static const String verifyResetToken = 'verifyResetToken';
  static const String fcmUpdate = 'fcmUpdate';
  static const String otpVerification = 'otpVerification';
  static const String resendTokenEmailChange = 'ResendTokenEmailChange';
  static const String updateBookingStatusByUser = 'updateBookingStatusByUser';
  static const String resendOtp = 'ResendOtp';
  static const String changeEmail = 'changeEmail';
  static const String sendMobileLoginOtp = 'sendMobileLoginOtp';
  static const String checkEmail = 'checkEmail';
  static const String userMobileLogin = 'userMobileLogin';
  static const String getAllCategories = 'getAllCategories';
  static const String checkMobileNumber = 'checkMobileNumber';
  static const String changeMobileNumber = 'changeMobileNumber';
  static const String getItemPrices = 'getItemPrices';
  static const String bookItem = 'bookItem';
  static const String giveReviewByUser = 'giveReviewByUser';
  static const String updatePaymentStatusByUser = 'updatePaymentStatusByUser';
  static const String bookingRecord = 'bookingRecord';
  static const String deleteAccount = 'deleteAccount';
  static const String editProfile = 'editProfile';
  static const String uploadProfileImage = 'uploadProfileImage';
  static const String getgeneralSettings = 'getgeneralSettings';
  static const String staticPage = 'StaticPage';
  static const String sos = 'sos';
  
}
