# Firebase iOS por flavor

- **dev** → `dev/GoogleService-Info.plist` (bundle `com.ricindigus.tsm.pedidosapp.dev`)
- **prod** → `prod/GoogleService-Info.plist` (bundle `com.ricindigus.tsm.pedidosapp.prod`)

Antes de publicar, en cada proyecto de Firebase registra la app iOS con ese **Bundle ID** y, si Firebase te da un plist distinto, **reemplaza** el archivo de esta carpeta (el `GOOGLE_APP_ID` debe coincidir con el de la consola).

El script de build copia el plist correcto a `Runner/GoogleService-Info.plist` según el flavor.
