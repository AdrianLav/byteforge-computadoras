/**
 * Catálogo recibido desde Supabase y consumido por el render del catálogo.
 */
export const catalogoProductos = [];

export function reemplazarCatalogo(productos) {
  catalogoProductos.splice(0, catalogoProductos.length, ...productos);
}
