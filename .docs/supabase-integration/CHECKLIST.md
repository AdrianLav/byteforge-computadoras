# Integración con Supabase: checklist

- [x] Revisar el proyecto y validar el PDF. `InformeByteForgehito4 (1).pdf`, 1 página; texto extraído con PDFKit y revisado visualmente. Proyecto estático sin persistencia remota previa.
- [x] Documentar el modelo y su correspondencia con la aplicación. Entidades, cardinalidades, operaciones, permisos, pruebas y decisiones abiertas en [ANALISIS.md](./ANALISIS.md).
- [x] Crear o identificar el proyecto remoto y enlazarlo mediante CLI. `byteforge-computadoras`, región `sa-east-1`, ref `kmsncxeajnwizkqwkjmj`, único proyecto de la organización, `ACTIVE_HEALTHY`; validado en `supabase projects list`.
- [x] Crear, aplicar y verificar migraciones y permisos. Cuatro migraciones aplicadas; `migration list` concuerda, `db push --dry-run` indica `upToDate: true`; `db lint` sin errores; RLS habilitado en las cinco tablas.
- [x] Configurar el SDK y las variables de entorno. Cliente en `supabase-client.js`, ejemplo en `.env.example`, valores reales en `.env.local` (modo 0600, ignorado); el frontend no contiene clave `service_role`.
- [x] Integrar y comprobar las operaciones CRUD definidas por el PDF, con restricciones documentadas.
  - [x] `producto` — lectura pública activa; crear, actualizar y desactivar como `admin` verificados dentro de una transacción revertida; borrado físico no permitido.
  - [x] `pedido` — checkout real crea pedido/línea; personal lee; edición recalcula el total; cancelación, desactivación lógica y anonimización comprobadas transaccionalmente; sin búsqueda pública por número.
  - [x] `linea_pedido` — alta atómica con pedido, lectura autorizada por personal y edición antes del pago verificadas; sin borrado independiente.
  - [x] `pago` — registro de transferencia verificada por `ventas` y contra entrega al marcar la entrega; lectura por `admin`; `ventas` y usuarios sin rol no ven referencias/pagos.
  - [x] `configuracion` — lectura pública del 16%; actualización por `admin` validada dentro de una transacción revertida; 16% sigue provisional.
  - [ ] Pasarela de tarjeta, webhooks y correo. Pendiente por alcance: el PDF los identifica como etapa futura; no se capturan datos de tarjeta ni se declara un cobro real.
- [x] Verificar persistencia, permisos y funcionamiento del proyecto. La UI cargó 12 productos, filtro/búsqueda/vacío y recarga comprobados; checkout registró `BF-000001` con total recalculado; permisos anon/no personal/staff/admin verificados con clave pública y claims JWT de prueba.
- [x] Documentar la ejecución y los pendientes. Requisitos, credenciales locales, migraciones, seed, lint, advertencia de configuración y siguientes tareas en [EJECUCION.md](./EJECUCION.md).

## Evidencia y límites de las pruebas

- `npm test`: 2 pruebas aprobadas. `npm run build`: compilación correcta.
- `npx supabase db lint --remote --schema public --fail-on warning`: sin errores. Las cinco tablas públicas tienen RLS habilitado.
- Lectura remota con clave pública: 12 productos activos y tasa `0.16`. Checkout vía la interfaz creó pedido real y línea; una consulta PostgreSQL confirmó subtotal, impuesto, total y línea persistidos.
- Se rechazaron lectura pública de pedidos, modificación pública de catálogo, cantidad 11 y envío de un campo `numero_tarjeta`.
- `SET ROLE authenticated` con claims de prueba verificó rol `ventas` (leer/actualizar/confirmar transferencia), `despacho` (preparar/enviar/entregar), `admin` (CRUD de producto/configuración, lectura de pago) y usuario sin rol (lectura denegada). Estos tests no reemplazan la comprobación con cuentas Auth reales.
- Se probaron ambos flujos de pago no electrónicos. Los dos pedidos/las líneas/pagos creados para la prueba se eliminaron después; verificación final: 0 pedidos, 0 líneas, 0 pagos temporales y 12 productos de semilla.
- No había Docker ni `psql`; la migración se validó y ejecutó en el remoto, y `db lint` está limpio.
- `supabase config diff --remote` reportó diferencias entre valores por defecto local/remoto (p. ej., confirmación de email, MFA, redirects y pooler). No se hizo `config push` para no cambiar Auth u otros servicios sin decisión explícita.

## Siguiente acción para retomar

Confirmar la tasa fiscal y el proveedor de pago antes de aceptar cobros; provisionar usuarios Auth para el personal asignando roles solo en `app_metadata`; validar políticas con cuentas reales; desarrollar un panel interno protegido y, si se requiere, Edge Function/webhook de pasarela. Mantener el proyecto enlazado y no volver a ejecutar `supabase init` ni crear recursos duplicados.
