import 'dart:async';
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

  /// Helper to convert Dart data structures to pure JS ArrayBuffers
  dynamic _toJSBuffer(Uint8List list) {
    return js_util.getProperty(list, 'buffer');
  }

  /// STEP 1: ENROLL
  Future<bool> enrollBiometrics(String email) async {
    try {
      print("WebAuthn: Preparing enrollment for $email...");
      final dynamic credentials = js_util.getProperty(html.window.navigator, 'credentials');
      
      final Uint8List challenge = Uint8List.fromList(List.generate(32, (i) => i));
      final Uint8List userId = Uint8List.fromList(email.codeUnits);

      final dynamic publicKey = js_util.newObject();
      js_util.setProperty(publicKey, 'challenge', _toJSBuffer(challenge));
      
      final dynamic rp = js_util.newObject();
      js_util.setProperty(rp, 'name', 'SkyFit Pro');
      js_util.setProperty(rp, 'id', 'localhost');
      js_util.setProperty(publicKey, 'rp', rp);

      final dynamic user = js_util.newObject();
      js_util.setProperty(user, 'id', _toJSBuffer(userId));
      js_util.setProperty(user, 'name', email);
      js_util.setProperty(user, 'displayName', email);
      js_util.setProperty(publicKey, 'user', user);

      // FIX: Manually build the algorithms list to ensure it's a JS Array
      // This solves the "missing algorithm identifiers" warning in Chrome.
      final dynamic algList = js_util.callConstructor(js_util.getProperty(html.window, 'Array'), []);
      
      final dynamic alg1 = js_util.newObject();
      js_util.setProperty(alg1, 'type', 'public-key');
      js_util.setProperty(alg1, 'alg', -7); // ES256
      js_util.callMethod(algList, 'push', [alg1]);

      final dynamic alg2 = js_util.newObject();
      js_util.setProperty(alg2, 'type', 'public-key');
      js_util.setProperty(alg2, 'alg', -257); // RS256
      js_util.callMethod(algList, 'push', [alg2]);

      js_util.setProperty(publicKey, 'pubKeyCredParams', algList);

      final dynamic authSelection = js_util.newObject();
      js_util.setProperty(authSelection, 'authenticatorAttachment', 'platform');
      js_util.setProperty(authSelection, 'userVerification', 'required');
      js_util.setProperty(authSelection, 'residentKey', 'preferred');
      js_util.setProperty(publicKey, 'authenticatorSelection', authSelection);
      
      js_util.setProperty(publicKey, 'timeout', 60000);

      final dynamic options = js_util.newObject();
      js_util.setProperty(options, 'publicKey', publicKey);

      print("WebAuthn: Triggering browser 'create' prompt...");
      final dynamic result = await js_util.promiseToFuture(js_util.callMethod(credentials, 'create', [options]));
      
      if (result != null) {
        print("WebAuthn: Enrollment Successful.");
        return true;
      }
      return false;
    } catch (e) {
      print("WebAuthn: Enrollment Error: $e");
      return false;
    }
  }

  /// STEP 2: AUTHENTICATE
  Future<bool> authenticate() async {
    try {
      print("WebAuthn: Preparing authentication...");
      final dynamic credentials = js_util.getProperty(html.window.navigator, 'credentials');
      final Uint8List challenge = Uint8List.fromList(List.generate(32, (i) => i));

      final dynamic publicKey = js_util.newObject();
      js_util.setProperty(publicKey, 'challenge', _toJSBuffer(challenge));
      js_util.setProperty(publicKey, 'timeout', 60000);
      js_util.setProperty(publicKey, 'userVerification', 'required');
      
      final dynamic options = js_util.newObject();
      js_util.setProperty(options, 'publicKey', publicKey);

      print("WebAuthn: Triggering browser 'get' prompt...");
      final dynamic result = await js_util.promiseToFuture(js_util.callMethod(credentials, 'get', [options]));
      
      if (result != null) {
        print("WebAuthn: Verification Successful.");
        return true;
      }
      return false;
    } catch (e) {
      print("WebAuthn: Verification Failed: $e");
      return false;
    }
  }
}
