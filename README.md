# AllSell – Tienda virtual multivendedor

Arquitectura: **Navegador (HTML/JS) → Azure Static Web Apps (hosting) → Supabase (Auth + PostgreSQL + Storage)**.

```
allsell-azure/
├── site/                         ← lo que se publica en Azure
│   ├── index.html                (la tienda, sin build)
│   ├── config.js                 (URL y clave de Supabase)
│   └── staticwebapp.config.json  (cabeceras de seguridad y caché de Azure)
├── schema.sql                    (base de datos + seguridad RLS, se ejecuta en Supabase)
└── README.md
```

## Pasos de despliegue

### 1. Supabase (base de datos y seguridad)
1. Crea un proyecto en https://supabase.com.
2. **SQL Editor → New query**: pega todo `schema.sql` y ejecuta (**Run**).
3. **Authentication → Providers → Email**: para la demostración, desactiva "Confirm email" (así el registro entra directo).
4. **Project Settings → API**: copia `Project URL` y la clave `anon public`.
5. Pégalas en **`site/config.js`** (`SUPABASE_URL` y `SUPABASE_KEY`).

### 2. Azure Static Web Apps (publicación)

Elige **una** de las dos opciones. Ambas usan el plan **Free**.

#### Opción A · Desde GitHub (recomendada, se redespliega sola con cada `git push`)
1. Sube esta carpeta a un repositorio de GitHub.
2. En https://portal.azure.com → **Crear un recurso → Static Web App**.
3. Plan **Free**, elige tu suscripción/grupo de recursos y un nombre (p. ej. `allsell`).
4. **Detalles de implementación**: Origen **GitHub** → autoriza y selecciona repo y rama.
5. **Detalles de compilación**: Valor preestablecido **Custom** y
   - Ubicación de la aplicación: `/site`
   - Ubicación de Api: *(vacío)*
   - Ubicación de salida: *(vacío)*
6. **Revisar y crear**. Azure agrega un workflow en `.github/workflows/` y publica solo.
7. En el recurso, la pestaña **Información general** muestra la URL pública: `https://<nombre>.azurestaticapps.net`.

#### Opción B · Sin GitHub (Azure CLI + SWA CLI)
```bash
az login
az group create -n rg-allsell -l eastus2
az staticwebapp create -n allsell -g rg-allsell -l eastus2 --sku Free
# token de despliegue
TOKEN=$(az staticwebapp secrets list -n allsell -g rg-allsell --query "properties.apiKey" -o tsv)
# publicar la carpeta site/
npx @azure/static-web-apps-cli deploy ./site --deployment-token "$TOKEN" --env production
# URL pública
az staticwebapp show -n allsell -g rg-allsell --query "defaultHostname" -o tsv
```

> Alternativa muy simple: una **Storage Account → Static website** (habilitar, y subir el contenido de `site/` al contenedor `$web`). Funciona, pero Static Web Apps da HTTPS gratis, dominio propio y cabeceras de seguridad.

### 3. Supabase: permitir tu URL de Azure
En **Authentication → URL Configuration** pon como *Site URL* tu `https://<nombre>.azurestaticapps.net` (y agrégala en *Redirect URLs*). Así los correos de confirmación (si los activas) apuntan a tu sitio.

### 4. Prueba rápida
1. Abre el enlace → **avatar → Regístrate**.
2. **Vender → Mi tienda**: publica 3-4 productos con imagen, categoría y etiqueta (Nuevo / Oferta / Más vendido).
3. Agrega al carrito → **Finalizar compra** → confirmación.
4. Recarga la página: sesión, productos y carrito siguen ahí.
5. En Supabase **Table Editor → orders / order_items**: verifica el pedido guardado.

### Probar en local (antes de subir)
```bash
cd site && python3 -m http.server 8080   # abre http://localhost:8080
```

## Cumplimiento de la rúbrica

| Criterio | Cómo se cumple | Evidencia para mostrar |
|---|---|---|
| Servicio con arquitectura en la nube | Frontend en Azure Static Web Apps + Backend como servicio (Supabase: Auth, PostgreSQL, Storage) | Diagrama de arquitectura |
| Acceso por internet | URL pública `*.azurestaticapps.net` con HTTPS | Abrirla desde el celular |
| Cargado en plataforma en línea | Despliegue en Azure desde GitHub / CLI | Portal de Azure (recurso Static Web App en estado "Ready") |
| Registro de seguridad | Supabase Auth (contraseñas cifradas) + RLS: cada vendedor solo edita/elimina sus productos; cada comprador solo ve sus pedidos; subida de imágenes solo a su carpeta; el HTML escapa el texto de usuarios (anti-XSS); cabeceras de seguridad en `staticwebapp.config.json` | Pestaña *Authentication → Users* y *Policies* |
| Mantiene la información | PostgreSQL: profiles, categories, products, orders, order_items | *Table Editor* con datos |
| Que funcione | Registro, login, CRUD de productos, búsqueda y filtros, carrito, pedido simulado y confirmación | Demo en vivo |

## Notas
- El pago es simulado (no hay pasarela): se registra el pedido y se muestra confirmación.
- El carrito y los favoritos se guardan en `localStorage` del navegador; los pedidos, productos y usuarios, en Supabase.
- Prueba de seguridad útil para la sustentación: inicia sesión con dos usuarios y comprueba que uno no puede editar ni eliminar los productos del otro.
