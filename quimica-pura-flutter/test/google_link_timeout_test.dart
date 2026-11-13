// Prueba del arreglo de Google en 7.4 (Kristian): el inicio
// anónimo con VPN en Cuba tarda más de 5 s y el timeout viejo de
// 5 s lo mataba con 'link:unknown' sin que saliera el selector.
// Ahora espera 15 s y el timeout deja 'link:timeout_anon'.
// Se prueba el ayudante waitForAnonymous con tiempo falso
// (fake_async): sin Firebase real, pero con la misma lógica.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quimica_pura/services/auth_service.dart';

void main() {
  group('Google 7.4: timeout del inicio anónimo', () {
    test('el timeout es 15 s (no 5)', () {
      expect(FirebaseAuthProvider.kAnonymousLinkTimeout,
          const Duration(seconds: 15));
    });

    test('un inicio lento de 8 s YA NO se rinde (antes moría a los 5)', () {
      fakeAsync((async) {
        final slow =
            Future<String>.delayed(const Duration(seconds: 8), () => 'ok');
        String? got;
        FirebaseAuthProvider.waitForAnonymous(slow).then((v) => got = v);
        async.elapse(const Duration(seconds: 8));
        async.flushMicrotasks();
        expect(got, 'ok');
        expect(FirebaseAuthProvider().lastGoogleError, isNull);
      });
    });

    test('si no llega en 15 s, devuelve null con link:timeout_anon', () {
      fakeAsync((async) {
        final never = Completer<String>().future;
        String? got = 'pendiente';
        FirebaseAuthProvider.waitForAnonymous(never).then((v) => got = v);
        async.elapse(const Duration(seconds: 15));
        async.flushMicrotasks();
        expect(got, isNull);
        expect(FirebaseAuthProvider().lastGoogleError, 'link:timeout_anon');
      });
    });

    test('un inicio rápido devuelve el valor sin tocar el código', () {
      fakeAsync((async) {
        String? got;
        FirebaseAuthProvider.waitForAnonymous(Future.value('ok'))
            .then((v) => got = v);
        async.flushMicrotasks();
        expect(got, 'ok');
        expect(FirebaseAuthProvider().lastGoogleError, isNull);
      });
    });
  });
}
