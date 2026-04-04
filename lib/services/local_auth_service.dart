import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class LocalAuthService {
  Future<bool> isBiometricAvailable() async {
    if (!kIsWeb) return false;
    try {
      final dynamic publicKeyCredential = js_util.getProperty(html.window, 'PublicKeyCredential');
      if (publicKeyCredential == null) return false;
      final dynamic isAvailablePromise = js_util.callMethod(publicKeyCredential, 'isUserVerifyingPlatformAuthenticatorAvailable', []);
      return await js_util.promiseToFuture(isAvailablePromise);
    } catch (e) {
      return js_util.hasProperty(html.window.navigator, 'credentials');
    }
  }

  dynamic _toJSBuffer(Uint8List list) => js_util.getProperty(list, 'buffer');

  /// STEP 1: ENROLL
  Future<bool> enrollBiometrics(String email, {String? fullName}) async {
    try {
      print("WebAuthn: Enrolling $email...");
      final dynamic credentials = js_util.getProperty(html.window.navigator, 'credentials');
      final Uint8List challenge = Uint8List.fromList(List.generate(32, (i) => i));
      final Uint8List userId = Uint8List.fromList(utf8.encode(email));

      final dynamic publicKey = js_util.newObject();
      js_util.setProperty(publicKey, 'challenge', _toJSBuffer(challenge));
      
      final dynamic rp = js_util.newObject();
      js_util.setProperty(rp, 'name', 'SkyFit Pro');
      js_util.setProperty(rp, 'id', html.window.location.hostname);
      js_util.setProperty(publicKey, 'rp', rp);

      final dynamic user = js_util.newObject();
      js_util.setProperty(user, 'id', _toJSBuffer(userId));
      js_util.setProperty(user, 'name', email);
      js_util.setProperty(user, 'displayName', (fullName != null && fullName.isNotEmpty) ? fullName : email);
      js_util.setProperty(publicKey, 'user', user);

      final dynamic algList = js_util.callConstructor(js_util.getProperty(html.window, 'Array'), []);
      final dynamic alg1 = js_util.newObject();
      js_util.setProperty(alg1, 'type', 'public-key');
      js_util.setProperty(alg1, 'alg', -7);
      js_util.callMethod(algList, 'push', [alg1]);
      js_util.setProperty(publicKey, 'pubKeyCredParams', algList);

      final dynamic authSelection = js_util.newObject();
      js_util.setProperty(authSelection, 'authenticatorAttachment', 'platform');
      js_util.setProperty(authSelection, 'userVerification', 'preferred');
      js_util.setProperty(authSelection, 'residentKey', 'preferred');
      js_util.setProperty(publicKey, 'authenticatorSelection', authSelection);
      
      final dynamic options = js_util.newObject();
      js_util.setProperty(options, 'publicKey', publicKey);

      await js_util.promiseToFuture(js_util.callMethod(credentials, 'create', [options]));
      return true;
    } catch (e) {
      print("WebAuthn Enrollment Error: $e");
      return false;
    }
  }

  /// STEP 2: AUTHENTICATE
  /// Returns a Map with 'success' (bool) and 'email' (String?)
  Future<Map<String, dynamic>> authenticate() async {
    try {
      print("WebAuthn: Requesting authentication...");
      final dynamic credentials = js_util.getProperty(html.window.navigator, 'credentials');
      final Uint8List challenge = Uint8List.fromList(List.generate(32, (i) => i));

      final dynamic publicKey = js_util.newObject();
      js_util.setProperty(publicKey, 'challenge', _toJSBuffer(challenge));
      js_util.setProperty(publicKey, 'userVerification', 'required');
      js_util.setProperty(publicKey, 'rpId', html.window.location.hostname);
      
      final dynamic options = js_util.newObject();
      js_util.setProperty(options, 'publicKey', publicKey);

      final dynamic result = await js_util.promiseToFuture(js_util.callMethod(credentials, 'get', [options]));
      
      if (result != null) {
        final dynamic response = js_util.getProperty(result, 'response');
        final ByteBuffer? userHandle = js_util.getProperty(response, 'userHandle');
        
        String? selectedEmail;
        if (userHandle != null) {
          selectedEmail = utf8.decode(userHandle.asUint8List());
          print("WebAuthn: User selected in browser: $selectedEmail");
        }
        
        return {
          'success': true,
          'email': selectedEmail,
        };
      }
      return {'success': false};
    } catch (e) {
      print("WebAuthn Verification Error: $e");
      return {'success': false};
    }
  }
}
