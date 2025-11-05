# slatereduc

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Traductions dynamiques (Deepseek)

Cette application peut récupérer des traductions automatiques pour toutes les chaînes de l'application en utilisant l'API Deepseek. Par sécurité la clé API **ne doit pas** être stockée dans le code source ni dans l'application : elle est fournie uniquement au moment du build/exécution via une variable d'environnement compile‑time.

- Nom de la variable utilisée dans le code : `DEESEEK_API_KEY`
- La lecture se fait uniquement par `String.fromEnvironment('DEESEEK_API_KEY')` (compile‑time `--dart-define`).

### Exemples (développement)

Lancer en mode debug en passant la clé (ne pas committer cette commande avec la clé) :

```bash
flutter run -d <device-id> --dart-define=DEESEEK_API_KEY="VOTRE_CLE_REELLE"
```

Construire un APK/iOS release :

```bash
flutter build apk --release --dart-define=DEESEEK_API_KEY="VOTRE_CLE_REELLE"
flutter build ios --release --dart-define=DEESEEK_API_KEY="VOTRE_CLE_REELLE"
```

### Snippet CI (GitHub Actions)

Exemple minimal pour injecter la clé depuis les secrets GitHub (ne pas stocker la clé dans le repo) :

```yaml
name: Build APK
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 'stable'

      - name: Build APK
        env:
          DEESEEK_API_KEY: ${{ secrets.DEESEEK_API_KEY }}
        run: |
          flutter pub get
          flutter build apk --release --dart-define=DEESEEK_API_KEY="$DEESEEK_API_KEY"
```

Adapte ce snippet à ton pipeline (GitLab, Bitrise, etc.) : l'idée est la même — stocker la clé dans les secrets CI et l'injecter au moment du build via `--dart-define`.

### Debug & logs

Pendant le développement, le service de traduction écrit des logs en mode debug (conditionnés par `kDebugMode`). Pour diagnostiquer les réponses non‑JSON ou mal formées du modèle :

- Lance l'application en debug : `flutter run` (avec `--dart-define` si tu veux tester l'appel réel). Les `print(...)` apparaîtront dans la console.
- Tu peux aussi utiliser `flutter logs` pour suivre la sortie.
- Sur Android, `adb logcat | grep TranslationService` peut filtrer les messages.

Logs attendus quand il y a un problème :
- "[TranslationService] Deepseek returned content but no JSON could be extracted. Raw content:" suivi du texte brut renvoyé par le modèle.
- "[TranslationService] _extractJsonObject: failed to parse candidate JSON. Candidate:" suivi du JSON candidat et de l'erreur.
- Erreurs HTTP / exceptions sont aussi journalisées.

### Cache

Les traductions réussies sont mises en cache dans `SharedPreferences` sous la clé `dyn_trans_<lang>` (ex. `dyn_trans_en`). Cela évite de reinterroger l'API au lancement. Pour effacer le cache en développement :

- Désinstaller l'application ou
- Supprimer la clé `dyn_trans_<lang>` via un utilitaire de debug ou en modifiant temporairement le code pour supprimer cette entrée.

### Sécurité — recommandations importantes

- Ne commits jamais la clé API dans le dépôt.
- Même si la clé est injectée au build (avec `--dart-define`), une application compilée peut contenir des chaînes extraites par un attaquant motivé. Si la sécurité est critique :
  - implémente un proxy côté serveur qui détient la clé Deepseek et relaie les requêtes de traduction ; l'application appelle uniquement ton backend.
  - le backend peut appliquer quota, caching centralisé, rotation de clé et logging.

---

Si tu veux, j'ajoute une courte section supplémentaire qui montre comment ajouter un job complet CI (Android + iOS) ou bien j'implémente un petit script serveur proxy minimal (Node/Express) pour relayer les requêtes et protéger la clé. Dis‑moi ce que tu préfères.

Commande exemple pour lancer l'application en debug avec une clé API (ne pas committer cette ligne avec la clé réelle) :
// flutter run --dart-define=DEESEEK_API_KEY="VOTRE_CLE_REELLE"
