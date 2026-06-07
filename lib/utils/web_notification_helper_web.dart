import 'dart:js' as js;

void showWebNotificationImpl(String title, String body) {
  try {
    if (js.context.hasProperty('Notification')) {
      js.context.callMethod('eval', [
        """
        if (window.Notification) {
          Notification.requestPermission().then(function(permission) {
            if (permission === 'granted') {
              new Notification('$title', {
                body: '$body',
                icon: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCoqjP7BFZ5G58JZ9dWkY7i2nuxlXG22yw4_kp_tZDq9_LFlGpDXZN7CW3mbIisWHeikqi3HAtRW3GIE3Yv25gBdC20K-f5kYqQWbCYwr59BI8F9VS5Px2JuUIN1vtuKG2z93p-pIAb6Ea3-53UcUQzDXCzvR9Ar7P2inSnzRzOu5DHjU442uippjL0VveOFZ3BBk_TEVeMPIfcupH3xh7AswuFV2aHm9hmqFljLzwDutvFMQRHy3SZzrRekzi82S15S4nTDmbypbM'
              });
            }
          });
        }
        """
      ]);
    }
  } catch (e) {
    // Suppress web notification error
  }
}
