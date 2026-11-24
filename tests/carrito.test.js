import assert from "node:assert/strict";
import test from "node:test";
import {
  agregarAlCarrito,
  actualizarCantidad,
  calcularResumenCarrito,
  contarUnidadesCarrito,
  eliminarDelCarrito,
  establecerTasaImpuesto,
  itemsCarrito,
  vaciarCarrito,
} from "../script-1.js";

const producto = {
  id: "00000000-0000-4000-8000-000000000001",
  nombre: "Equipo de prueba",
  precio: 100,
};

test("calcula el resumen del carrito y permite actualizar y eliminar", () => {
  vaciarCarrito();
  establecerTasaImpuesto(0.16);
  agregarAlCarrito(producto, 2);

  assert.equal(contarUnidadesCarrito(), 2);
  assert.deepEqual(calcularResumenCarrito(), {
    subtotal: 200,
    impuestos: 32,
    total: 232,
  });

  actualizarCantidad(producto.id, 3);
  assert.equal(itemsCarrito[0].cantidad, 3);
  eliminarDelCarrito(producto.id);
  assert.equal(itemsCarrito.length, 0);
});

test("rechaza cantidades fuera del rango definido por el modelo", () => {
  vaciarCarrito();
  assert.throws(() => agregarAlCarrito(producto, 11), RangeError);
  agregarAlCarrito(producto, 10);
  assert.throws(() => agregarAlCarrito(producto, 1), RangeError);
  assert.throws(() => actualizarCantidad(producto.id, 11), RangeError);
  vaciarCarrito();
});
