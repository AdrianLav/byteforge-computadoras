# Análisis de integración con Supabase

## Fuente y lectura

- Fuente: [InformeByteForgehito4 (1).pdf](../../InformeByteForgehito4%20(1).pdf), página 1. Se abrió visualmente y se extrajo su texto con PDFKit de macOS. El documento se conserva sin cambios.
- Es una propuesta de diseño, no un esquema SQL definitivo. Las decisiones señaladas como abiertas abajo se mantienen explícitas.

## Modelo derivado del documento

| Entidad | Atributos y tipos PostgreSQL | Claves, nulabilidad, valores y restricciones |
|---|---|---|
| `producto` | `id uuid`, `nombre text`, `tipo text`, `categoria text`, `procesador text`, `ram text`, `almacenamiento text`, `tarjeta_grafica text`, `precio numeric(12,2)`, `imagen text`, `activo boolean`, fechas `timestamptz` | `id` PK UUID. `activo` inicia en `true`. `precio >= 0`. El PDF define activos/inactivos y precios administrables; los campos descriptivos se mapean del catálogo existente. Borrado físico no previsto; desactivar. |
| `pedido` | `id uuid`, `numero bigint identity`, `nombre_cliente varchar(60)`, `correo varchar(254)`, `telefono varchar(32)`, `direccion varchar(300)`, `ciudad varchar(80)`, `codigo_postal varchar(10)`, `metodo_pago text`, `estado text`, `activo boolean`, `referencia_pago varchar(64)`, `cliente_id uuid`, `subtotal/impuestos/total numeric(12,2)`, `tasa_impuesto numeric(5,4)`, fechas `timestamptz` | `id` PK inmutable; `numero` único, autogenerado; `cliente_id` opcional para cuentas futuras, FK a `auth.users(id)` con `ON DELETE SET NULL`; `codigo_postal` opcional según la recomendación del PDF. Estado inicial `pendiente_pago`; activo inicial `true`; fechas automáticas. Importe y tasa no se aceptan del cliente. El pedido no se borra físicamente; anonimización posterior conservando el historial. |
| `linea_pedido` | `id uuid`, `pedido_id uuid`, `producto_id uuid`, `cantidad integer`, `precio_unitario numeric(12,2)`, `subtotal numeric(12,2)` | PK `id`; FK a pedido y producto, ambas `ON DELETE RESTRICT`; cantidad 1–10; precio copiado al comprar; subtotal calculado. El checkout escribe las líneas atómicamente con el pedido. |
| `pago` | `id uuid`, `pedido_id uuid`, `proveedor text`, `referencia_pago varchar(64)`, `estado text`, `importe numeric(12,2)`, `creado_en timestamptz` | PK `id`; FK `pedido_id` `ON DELETE RESTRICT`; referencia única cuando existe. El número/vencimiento de tarjeta nunca se almacenan. Los intentos se conservan; no hay borrado físico. |
| `configuracion` | `id boolean`, `tasa_impuesto numeric(5,4)`, `modificado_en timestamptz` | Singleton con `id = true`; tasa entre 0 y 1. El código actual usa 16%; el PDF pide confirmar la tasa aplicable y hacerla configurable. La migración conserva 0.16 como valor provisional, no como asesoría fiscal. |

### Relaciones y cardinalidades (página 1, sección 08)

- `producto 1 — 0..N linea_pedido`: una línea apunta a un producto; los productos se desactivan en vez de eliminarse.
- `pedido 1 — 1..N linea_pedido`: cada pedido debe contener una o más líneas; pedido y líneas se crean en una transacción.
- `pedido 1 — 0..N pago`: se permiten varios intentos por pedido; el esquema conserva su historial.
- Una futura cuenta podría enlazarse opcionalmente por `pedido.cliente_id`. El flujo actual es de cliente invitado y no crea cuentas.

## Matriz de correspondencia PDF → app → verificación

| Página/sección | Entidad / operación | Flujo y archivo actual | Integración y verificación |
|---|---|---|---|
| 03, 05 | `producto` / leer catálogo | Catálogo en memoria, `script-2.js`; render, filtros y búsqueda en `script.js` | Cargar productos activos de Supabase; comprobar lista, filtro, búsqueda y vacío. |
| 05, 09 | `pedido`, `linea_pedido` / crear | Carrito y checkout en `script-1.js`, `index.html`, `script.js` | RPC transaccional recibe contacto, método e IDs/cantidades; servidor valida y calcula con catálogo/configuración vigente. |
| 09 | `pedido`, `linea_pedido` / leer | No existe pantalla de personal | Solo `ventas`, `despacho` y `admin` autenticados; cliente invitado no busca pedidos de terceros por número. |
| 09 | `pedido` / actualizar | No existe pantalla de personal ni modificación de pedidos ya creados | La matriz limita cambios de datos/líneas al personal antes del pago; definir y probar el flujo de personal antes de exponerlo. |
| 07, 09 | `pedido` / cancelar y desactivar | No existe operación de despacho en el frontend | Cancelar conserva el registro; desactivación oculta de listados; sin `DELETE` físico. |
| 10 | `producto` / crear, leer, actualizar, desactivar | Catálogo actual solo es lectura local | Lectura pública solo de activos; escritura administrativa mediante rol `admin`; no se borra físicamente. |
| 10 | `pago` / crear, leer | Pasarela no existe; el pago se simula | La migración permite a `ventas` registrar la confirmación de una transferencia verificada con referencia; lectura a `admin`. Pasarela de tarjeta pendiente. |
| 10 | `configuracion` / leer, crear, actualizar | Tasa `0.16` fija en `script-1.js` | Lectura pública y escritura por `admin`; sin borrado. El 16% es provisional. |
| 11–12 | Permisos, privacidad | No hay inicio de sesión ni panel de personal; la confirmación original usaba `innerHTML` con datos del cliente | RLS y funciones verifican roles en JWT `app_metadata`; salida dinámica escapada/textual. RLS se probó remotamente con claims sintéticos de `ventas`, `despacho`, `admin` y usuario sin rol; no se crearon cuentas de personal. |

## Roles y acceso requerido

- **Público/invitado:** puede leer productos activos y la tasa; puede crear un pedido únicamente por la función validada. La respuesta de checkout contiene el número y un recibo, no una API de consulta del pedido por número. No puede leer datos de pedidos, pagos o datos personales.
- **Personal autenticado:** rol confiable en `app_metadata.role`, asignado por un administrador, nunca por el cliente. `ventas`, `despacho` y `admin` pueden leer pedidos según la matriz; modificaciones restringidas por rol/estado. **Admin** gestiona catálogo, tasa y referencias de pago.
- **Pago:** la pasarela futura debe escribir/verificar pagos desde servidor/Edge Function con secretos privados. No se implementa ni se simula una confirmación real.
- RLS no considera que ocultar controles en JavaScript sea autorización. No se concede `service_role` al navegador.

## Diferencias y decisiones abiertas

- Los IDs locales actuales eran 1–12; el PDF requiere UUID. Los doce productos existentes se sembraron con UUID estables y repetibles.
- El carrito usa el navegador para mostrar importes; la base de datos recalculará los importes autoritativos al crear el pedido. La tasa 0.16 conserva el comportamiento actual, pendiente de confirmación.
- El PDF recomienda que una pasarela externa capture los datos de tarjeta; se eliminaron los campos propios de tarjeta. Sin pasarela, el pedido queda `pendiente_pago` y la interfaz no dice “pagado” ni “correo enviado”.
- Las transferencias pueden marcarse pagadas por `ventas` después de su verificación manual; contra entrega avanza por preparación/envío y registra el cobro confirmado al marcarse entregado.
- No se exponen lecturas públicas de pedidos, incluso por número. No hay cuentas de cliente en la aplicación actual.
- El proyecto remoto está creado, enlazado y verificado. Los usuarios/roles de personal aún no se crearon y no hay interfaz de personal; las pruebas RLS usan `SET ROLE authenticated` y claims sintéticos, no sesiones reales.
- El catálogo y el checkout usan el proyecto real. Una pasarela de tarjeta, correo transaccional y confirmación automatizada siguen fuera del alcance porque el PDF los define como etapa futura; no se reciben datos de tarjeta.

## CLI y proyecto remoto

Se comprobó `npx supabase --version` (3.3.0), se validaron `init`, `projects create`, `link`, `db push`, `migration list` y `config push`. Se creó `byteforge-computadoras` en `sa-east-1`, ref `kmsncxeajnwizkqwkjmj`, estado `ACTIVE_HEALTHY`, bajo la única organización disponible. La base está enlazada; las cuatro migraciones aparecen aplicadas y el catálogo tiene doce productos activos. `config diff --remote` mostró diferencias peligrosas/no intencionadas entre defaults locales y Auth remoto; no se ejecutó `config push`. Evidencia y comandos en [EJECUCION.md](./EJECUCION.md).
