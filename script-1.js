/**
 * carrito.js
 * Contiene toda la lógica de estado y cálculo del carrito de compras.
 * No manipula el DOM directamente: expone funciones puras y un array
 * de estado que principal.js se encarga de renderizar.
 */

let tasaImpuesto = 0.16;

export let itemsCarrito = [];

/** Agrega un producto al carrito. Si ya existe, incrementa la cantidad. */
export function agregarAlCarrito(producto, cantidad = 1) {
  if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > 10) {
    throw new RangeError("La cantidad debe ser un entero entre 1 y 10.");
  }

  const itemExistente = itemsCarrito.find((item) => item.producto.id === producto.id);

  if (itemExistente) {
    if (itemExistente.cantidad + cantidad > 10) {
      throw new RangeError("El máximo permitido es 10 unidades por equipo.");
    }
    itemExistente.cantidad += cantidad;
  } else {
    itemsCarrito.push({ producto, cantidad });
  }
}

/** Elimina por completo un producto del carrito. */
export function eliminarDelCarrito(idProducto) {
  itemsCarrito = itemsCarrito.filter((item) => item.producto.id !== idProducto);
}

/** Cambia la cantidad de un producto ya presente en el carrito. */
export function actualizarCantidad(idProducto, nuevaCantidad) {
  const item = itemsCarrito.find((item) => item.producto.id === idProducto);
  if (!item) return;

  if (nuevaCantidad <= 0) {
    eliminarDelCarrito(idProducto);
    return;
  }
  if (!Number.isInteger(nuevaCantidad) || nuevaCantidad > 10) {
    throw new RangeError("El máximo permitido es 10 unidades por equipo.");
  }
  item.cantidad = nuevaCantidad;
}

/** Vacía completamente el carrito (se usa tras confirmar un pedido). */
export function vaciarCarrito() {
  itemsCarrito = [];
}

/** Devuelve la cantidad total de unidades en el carrito. */
export function contarUnidadesCarrito() {
  return itemsCarrito.reduce((total, item) => total + item.cantidad, 0);
}

/** Calcula subtotal, impuestos y total del carrito actual. */
export function calcularResumenCarrito() {
  const subtotal = itemsCarrito.reduce(
    (total, item) => total + item.producto.precio * item.cantidad,
    0
  );
  const impuestos = subtotal * tasaImpuesto;
  const total = subtotal + impuestos;

  return { subtotal, impuestos, total };
}

export function establecerTasaImpuesto(tasa) {
  if (!Number.isFinite(tasa) || tasa < 0 || tasa > 1) {
    throw new RangeError("La tasa de impuesto recibida no es válida.");
  }
  tasaImpuesto = tasa;
}

/** Da formato de moneda en bolivianos (Bs) a un número, con separador de miles. */
export function formatearMoneda(valor) {
  const valorFormateado = valor.toLocaleString("es-BO", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  return `Bs ${valorFormateado}`;
}
