class AppUtils {
  static String formatQueueNumber(int number) {
    return 'Q-${number.toString().padLeft(3, '0')}';
  }
}
