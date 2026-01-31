/// Cloudinary Configuration for PayroPOS
/// Using Cloudinary as free image storage alternative to Firebase Storage
class CloudinaryConfig {
  CloudinaryConfig._();

  // Your Cloudinary credentials
  static const String cloudName = 'ddj6xjkcm';
  static const String apiKey = '553964789651414';

  // Create an unsigned upload preset in Cloudinary Dashboard:
  // Settings > Upload > Upload presets > Add upload preset
  // Set "Signing Mode" to "Unsigned"
  // Name it: payropos_unsigned
  static const String uploadPreset = 'payropos_unsigned';

  // Upload URL
  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  // Folders for organizing images
  static const String productImagesFolder = 'payropos/products';
  static const String storeLogosFolder = 'payropos/stores';
  static const String userAvatarsFolder = 'payropos/avatars';
  static const String receiptsFolder = 'payropos/receipts';
}
