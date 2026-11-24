# Ejecución y operación

## Requisitos

- Node.js 20.19+ o 22.12+ y npm. El proyecto usa Vite y `@supabase/supabase-js`.
- Supabase CLI por `npx supabase` (verificada: 3.3.0).
- Cuenta y organización Supabase con capacidad disponible en el plan gratuito.
- Para aplicar recursos remotos: autenticación local de la CLI, contraseña de la base de datos cuando se solicite y URL/clave publicable del proyecto. No se guardan secretos en Git ni en el navegador.

## Proyecto remoto creado

- Proyecto: `byteforge-computadoras`, región `sa-east-1`, ref `kmsncxeajnwizkqwkjmj`, organización única disponible, estado `ACTIVE_HEALTHY`.
- Creado en el plan gratuito con tamaño predeterminado de la organización; la CLI rechazó especificar `--size` para una organización gratuita.
- La CLI está enlazada al ref anterior. La contraseña de base de datos generada se guardó en el Llavero de macOS, no en el repositorio ni en esta documentación.
- URL: `https://kmsncxeajnwizkqwkjmj.supabase.co`. La clave legacy `anon`/publicable está en `.env.local` (modo 0600, ignorado por Git); no se usa `service_role` en el cliente.

## Configuración de la aplicación

1. Copiar `.env.example` a `.env.local`.
2. Completar `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY` con valores del proyecto. La clave publicable está diseñada para el cliente y queda protegida por RLS; nunca copiar `service_role` o una clave secreta al frontend.
3. Ejecutar `npm install` y `npm run dev`. Para compilar: `npm run build`; para revisar `dist/`: `npm run preview`.

El `.env.local` está excluido por `.gitignore`. `.env.example` solo contiene nombres de variables.

## Migraciones y productos iniciales

- Esquema y RLS: `supabase/migrations/20261123235900_byteforge_orders.sql`.
- Corrección de lint checkout: `supabase/migrations/20261124010500_refine_order_creation.sql`.
- Confirmación manual de transferencia: `supabase/migrations/20261124011000_confirm_transfer_payment.sql`.
- Flujo contra entrega: `supabase/migrations/20261124011500_cash_on_delivery_flow.sql`.
- Catálogo inicial: `supabase/seed.sql`, con UUID fijos y `ON CONFLICT DO NOTHING`.
- `supabase/config.toml` activa la semilla. Se ejecutó conscientemente `npx supabase db push --include-seed --remote`; la verificación remota confirma 12 productos activos. La semilla es idempotente.
- Las cuatro migraciones están aplicadas. `npx supabase db push --dry-run --remote` responde `upToDate: true`; `npx supabase migration list --remote` muestra las cuatro versiones en ambos lados.
- `npx supabase db lint --remote --schema public --fail-on warning` terminó sin errores.
- `npx supabase config diff --remote` mostró 14 diferencias por valores predeterminados distintos, incluyendo confirmación de email/MFA y redirects. No se ejecutó `config push` para evitar cambios inesperados; Auth y ajustes del dashboard quedan como revisión manual.

## Seguridad, Auth y pagos

- Personal: crear/invitar cuentas manualmente desde Supabase Auth y asignar `app_metadata.role` desde un entorno confiable a `ventas`, `despacho` o `admin`. No asignar el rol con `user_metadata` ni desde la aplicación pública. Es requisito probar las políticas con cuentas de cada rol antes de producción.
- El catálogo activo y la tasa son públicos. Pedidos y líneas solo se leen con rol autorizado; los pagos solo los lee `admin`. El checkout público invoca `crear_pedido`, que valida entrada, lee precios/tasa del servidor y guarda pedido/líneas en una transacción.
- Personal autorizado puede ajustar un pedido pendiente con `actualizar_pedido_pendiente`; `ventas` puede cancelar pedidos pendientes, `despacho` avanza estados y `admin` puede desactivar o anonimizar conservando el historial.
- Una cuenta `ventas` puede registrar una transferencia verificada llamando `confirmar_transferencia(numero, referencia)`; la llamada crea el pago y marca el pedido pagado en una transacción. Contra entrega permite preparar/enviar un pedido pendiente; marcarlo como entregado crea el pago confirmado. No confirma cobros con tarjeta ni acredita depósitos automáticamente.
- No existe integración con pasarela de tarjeta. El checkout crea pedidos `pendiente_pago`; una transferencia solo pasa a pagada después de la confirmación manual de `ventas`, y contra entrega registra el pago al entregar. No se solicitan ni guardan números/vencimientos de tarjeta; no se envían correos. El proveedor/webhook debe implementarse en una Edge Function/servidor antes de aceptar cobros con tarjeta.
- La tasa 0.16 conserva el valor que ya presenta la aplicación, pero es provisional hasta confirmación fiscal. Un admin puede actualizarla desde una sesión confiable tras validar el criterio de negocio.
- No existe panel de personal en la aplicación actual. Las lecturas/actualizaciones de administración deben realizarse desde interfaces autenticadas que respeten estas funciones/políticas; no exponer datos de pedidos por número al público.
- La UI muestra cantidades/precios persistidos tras recarga; los filtros y búsqueda se mantienen y las estadísticas de catálogo se calculan dinámicamente.

## Pendientes de configuración manual

- Confirmar la tasa aplicable antes de anunciar el precio final.
- Crear personal inicial con metadatos de rol; revisar configuración de altas públicas de Auth y redirecciones en el proyecto remoto antes de cualquier `config push`.
- Integrar y revisar un panel protegido para operaciones de personal, y conectar pasarela de tarjeta/Edge Function antes de aceptar cobros reales.
- Las verificaciones RLS usaron claims sintéticos mediante `SET ROLE authenticated`; validar de nuevo con sesiones de cuentas reales antes de producción.
