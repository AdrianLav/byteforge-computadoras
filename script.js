import { supabase, errorConfiguracionSupabase } from "./supabase-client.js";
import {
  agregarAlCarrito,
  actualizarCantidad,
  calcularResumenCarrito,
  contarUnidadesCarrito,
  eliminarDelCarrito,
  establecerTasaImpuesto,
  formatearMoneda,
  itemsCarrito,
  vaciarCarrito,
} from "./script-1.js";
import { catalogoProductos, reemplazarCatalogo } from "./script-2.js";

const campoBusqueda = document.getElementById("campo-busqueda");
const filtrosCategoria = document.getElementById("filtros-categoria");
const grillaProductos = document.getElementById("grilla-productos");
const mensajeSinResultados = document.getElementById("mensaje-sin-resultados");
const textoResultados = document.getElementById("texto-resultados");
const estadoCatalogo = document.getElementById("estado-catalogo");
const totalProductos = document.getElementById("total-productos");
const totalCategorias = document.getElementById("total-categorias");

const botonCarrito = document.getElementById("boton-carrito");
const contadorCarrito = document.getElementById("contador-carrito");
const panelCarrito = document.getElementById("panel-carrito");
const fondoPanel = document.getElementById("fondo-panel");
const cerrarCarritoBtn = document.getElementById("cerrar-carrito");
const listaCarrito = document.getElementById("lista-carrito");
const carritoVacioMsg = document.getElementById("carrito-vacio");
const resumenCarrito = document.getElementById("resumen-carrito");
const valorSubtotal = document.getElementById("valor-subtotal");
const valorImpuestos = document.getElementById("valor-impuestos");
const valorTotal = document.getElementById("valor-total");
const etiquetaImpuestos = document.getElementById("etiqueta-impuestos");
const mensajeCarrito = document.getElementById("mensaje-carrito");
const botonPagar = document.getElementById("boton-pagar");

const modalCheckout = document.getElementById("modal-checkout");
const cerrarCheckoutBtn = document.getElementById("cerrar-checkout");
const formularioCheckout = document.getElementById("formulario-checkout");
const resumenPedidoModal = document.getElementById("resumen-pedido-modal");
const metodoPagoSelect = document.getElementById("metodo-pago");
const mensajeCheckout = document.getElementById("mensaje-checkout");
const botonConfirmarPedido = formularioCheckout.querySelector('[type="submit"]');

const modalConfirmacion = document.getElementById("modal-confirmacion");
const numeroOrdenSpan = document.getElementById("numero-orden");
const estadoPedidoSpan = document.getElementById("estado-pedido");
const detalleConfirmacion = document.getElementById("detalle-confirmacion");
const cerrarConfirmacionBtn = document.getElementById("cerrar-confirmacion");

let categoriaActiva = "Todas";
let terminoBusqueda = "";

function escaparHtml(valor) {
  return String(valor).replace(/[&<>"']/g, (caracter) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  })[caracter]);
}

function urlImagenSegura(valor) {
  try {
    const url = new URL(valor);
    return url.protocol === "https:" ? escaparHtml(url.href) : "";
  } catch {
    return "";
  }
}

function obtenerProductosFiltrados() {
  return catalogoProductos.filter((producto) => {
    const coincideCategoria =
      categoriaActiva === "Todas" || producto.categoria === categoriaActiva;
    const textoCompleto = [
      producto.nombre,
      producto.tipo,
      producto.procesador,
      producto.ram,
      producto.almacenamiento,
      producto.tarjetaGrafica,
    ].join(" ").toLowerCase();
    return coincideCategoria && textoCompleto.includes(terminoBusqueda.toLowerCase());
  });
}

function crearTarjetaProducto(producto) {
  const tarjeta = document.createElement("article");
  tarjeta.className = "tarjeta-producto";
  tarjeta.innerHTML = `
    <div class="tarjeta-producto__imagen-cont">
      <img src="${urlImagenSegura(producto.imagen)}" alt="${escaparHtml(producto.nombre)}" loading="lazy" />
      <span class="tarjeta-producto__categoria">${escaparHtml(producto.categoria)}</span>
    </div>
    <div class="tarjeta-producto__cuerpo">
      <h3 class="tarjeta-producto__nombre">${escaparHtml(producto.nombre)}</h3>
      <p class="tarjeta-producto__tipo">${escaparHtml(producto.tipo)}</p>
      <div class="especificaciones">
        <div class="especificaciones__item">
          <span class="especificaciones__etiqueta">PROCESADOR</span>
          <span class="especificaciones__valor">${escaparHtml(producto.procesador)}</span>
        </div>
        <div class="especificaciones__item">
          <span class="especificaciones__etiqueta">RAM</span>
          <span class="especificaciones__valor">${escaparHtml(producto.ram)}</span>
        </div>
        <div class="especificaciones__item">
          <span class="especificaciones__etiqueta">ALMACENAMIENTO</span>
          <span class="especificaciones__valor">${escaparHtml(producto.almacenamiento)}</span>
        </div>
        <div class="especificaciones__item">
          <span class="especificaciones__etiqueta">GRÁFICOS</span>
          <span class="especificaciones__valor">${escaparHtml(producto.tarjetaGrafica)}</span>
        </div>
      </div>
      <div class="tarjeta-producto__pie">
        <span class="tarjeta-producto__precio">${formatearMoneda(producto.precio)}</span>
        <button class="boton-agregar" data-id="${escaparHtml(producto.id)}">Agregar</button>
      </div>
    </div>
  `;
  return tarjeta;
}

function renderizarCatalogo() {
  const productosFiltrados = obtenerProductosFiltrados();
  grillaProductos.replaceChildren();
  totalProductos.textContent = String(catalogoProductos.length);
  totalCategorias.textContent = String(
    new Set(catalogoProductos.map((producto) => producto.categoria)).size
  );

  if (productosFiltrados.length === 0) {
    mensajeSinResultados.classList.remove("oculto");
  } else {
    mensajeSinResultados.classList.add("oculto");
    productosFiltrados.forEach((producto) => {
      grillaProductos.appendChild(crearTarjetaProducto(producto));
    });
  }

  textoResultados.textContent =
    productosFiltrados.length === catalogoProductos.length
      ? `Mostrando ${catalogoProductos.length} equipos`
      : `Mostrando ${productosFiltrados.length} de ${catalogoProductos.length} equipos`;
}

function mostrarMensaje(elemento, mensaje) {
  elemento.textContent = mensaje;
  elemento.classList.remove("oculto");
}

function limpiarMensaje(elemento) {
  elemento.textContent = "";
  elemento.classList.add("oculto");
}

function mapearProducto(row) {
  return {
    id: row.id,
    nombre: row.nombre,
    tipo: row.tipo,
    categoria: row.categoria,
    procesador: row.procesador,
    ram: row.ram,
    almacenamiento: row.almacenamiento,
    tarjetaGrafica: row.tarjeta_grafica,
    precio: Number(row.precio),
    imagen: row.imagen,
  };
}

async function cargarCatalogo() {
  if (!supabase) {
    mostrarMensaje(estadoCatalogo, errorConfiguracionSupabase);
    renderizarCatalogo();
    return;
  }

  estadoCatalogo.textContent = "Cargando catálogo…";
  try {
    const [{ data: productos, error: errorProductos }, { data: config, error: errorConfig }] =
      await Promise.all([
        supabase
          .from("productos")
          .select("id,nombre,tipo,categoria,procesador,ram,almacenamiento,tarjeta_grafica,precio,imagen")
          .eq("activo", true)
          .order("nombre"),
        supabase.from("configuracion").select("tasa_impuesto").eq("id", true).single(),
      ]);

    if (errorProductos) throw new Error(`No se pudo cargar el catálogo: ${errorProductos.message}`);
    if (errorConfig) throw new Error(`No se pudo cargar la tasa de impuesto: ${errorConfig.message}`);
    if (!Array.isArray(productos) || !config) {
      throw new Error("Supabase devolvió una respuesta incompleta para el catálogo.");
    }

    reemplazarCatalogo(productos.map(mapearProducto));
    establecerTasaImpuesto(Number(config.tasa_impuesto));
    etiquetaImpuestos.textContent =
      `Impuestos (${Number(config.tasa_impuesto) * 100}%)`;
    estadoCatalogo.textContent = productos.length === 0
      ? "El catálogo está vacío."
      : "";
    renderizarCatalogo();
  } catch (error) {
    mostrarMensaje(estadoCatalogo, error.message);
    renderizarCatalogo();
  }
}

filtrosCategoria.addEventListener("click", (evento) => {
  const chip = evento.target.closest(".chip");
  if (!chip) return;

  filtrosCategoria
    .querySelectorAll(".chip")
    .forEach((elemento) => elemento.classList.remove("chip--activo"));
  chip.classList.add("chip--activo");
  categoriaActiva = chip.dataset.categoria;
  renderizarCatalogo();
});

campoBusqueda.addEventListener("input", (evento) => {
  terminoBusqueda = evento.target.value.trim();
  renderizarCatalogo();
});

grillaProductos.addEventListener("click", (evento) => {
  const boton = evento.target.closest(".boton-agregar");
  if (!boton) return;

  const producto = catalogoProductos.find((item) => item.id === boton.dataset.id);
  if (!producto) return;

  try {
    agregarAlCarrito(producto, 1);
    limpiarMensaje(mensajeCarrito);
    renderizarCarrito();
    const textoOriginal = boton.textContent;
    boton.textContent = "Agregado ✓";
    boton.disabled = true;
    setTimeout(() => {
      boton.textContent = textoOriginal;
      boton.disabled = false;
    }, 700);
  } catch (error) {
    mostrarMensaje(mensajeCarrito, error.message);
  }
});

function crearItemCarrito(item) {
  const { producto, cantidad } = item;
  const elemento = document.createElement("div");
  elemento.className = "item-carrito";
  elemento.innerHTML = `
    <img src="${urlImagenSegura(producto.imagen)}" alt="${escaparHtml(producto.nombre)}" />
    <div>
      <p class="item-carrito__nombre">${escaparHtml(producto.nombre)}</p>
      <span class="item-carrito__precio">${formatearMoneda(producto.precio)} c/u</span>
      <div class="item-carrito__controles">
        <button class="item-carrito__cantidad-btn" data-accion="restar" data-id="${escaparHtml(producto.id)}" aria-label="Restar unidad">−</button>
        <span class="item-carrito__cantidad-valor">${cantidad}</span>
        <button class="item-carrito__cantidad-btn" data-accion="sumar" data-id="${escaparHtml(producto.id)}" aria-label="Sumar unidad">+</button>
      </div>
    </div>
    <div class="item-carrito__acciones">
      <span class="item-carrito__subtotal">${formatearMoneda(producto.precio * cantidad)}</span>
      <button class="item-carrito__eliminar" data-accion="eliminar" data-id="${escaparHtml(producto.id)}">Eliminar</button>
    </div>
  `;
  return elemento;
}

function renderizarCarrito() {
  listaCarrito.replaceChildren();
  const hayItems = itemsCarrito.length > 0;
  carritoVacioMsg.classList.toggle("oculto", hayItems);
  resumenCarrito.classList.toggle("oculto", !hayItems);
  itemsCarrito.forEach((item) => listaCarrito.appendChild(crearItemCarrito(item)));

  const { subtotal, impuestos, total } = calcularResumenCarrito();
  valorSubtotal.textContent = formatearMoneda(subtotal);
  valorImpuestos.textContent = formatearMoneda(impuestos);
  valorTotal.textContent = formatearMoneda(total);
  contadorCarrito.textContent = contarUnidadesCarrito();
  botonPagar.disabled = !hayItems;
}

listaCarrito.addEventListener("click", (evento) => {
  const boton = evento.target.closest("button[data-accion]");
  if (!boton) return;

  const idProducto = boton.dataset.id;
  const item = itemsCarrito.find((actual) => actual.producto.id === idProducto);
  if (!item) return;

  try {
    switch (boton.dataset.accion) {
      case "sumar":
        actualizarCantidad(idProducto, item.cantidad + 1);
        break;
      case "restar":
        actualizarCantidad(idProducto, item.cantidad - 1);
        break;
      case "eliminar":
        eliminarDelCarrito(idProducto);
        break;
      default:
        return;
    }
    limpiarMensaje(mensajeCarrito);
    renderizarCarrito();
  } catch (error) {
    mostrarMensaje(mensajeCarrito, error.message);
  }
});

function abrirPanelCarrito() {
  panelCarrito.classList.add("panel-carrito--abierto");
  fondoPanel.classList.remove("oculto");
}

function cerrarPanelCarrito() {
  panelCarrito.classList.remove("panel-carrito--abierto");
  fondoPanel.classList.add("oculto");
}

botonCarrito.addEventListener("click", abrirPanelCarrito);
cerrarCarritoBtn.addEventListener("click", cerrarPanelCarrito);
fondoPanel.addEventListener("click", () => {
  cerrarPanelCarrito();
  cerrarModal(modalCheckout);
  cerrarModal(modalConfirmacion);
});

function abrirModal(modal) {
  modal.classList.remove("oculto");
}

function cerrarModal(modal) {
  modal.classList.add("oculto");
}

function renderizarResumenPedido(contenedor) {
  const { subtotal, impuestos, total } = calcularResumenCarrito();
  const filasProductos = itemsCarrito.map((item) => `
    <div class="linea-resumen-pedido">
      <span>${item.cantidad} × ${escaparHtml(item.producto.nombre)}</span>
      <span>${formatearMoneda(item.producto.precio * item.cantidad)}</span>
    </div>
  `).join("");

  contenedor.innerHTML = `
    <h3>Resumen del pedido</h3>
    ${filasProductos}
    <div class="linea-resumen-pedido"><span>Subtotal</span><span>${formatearMoneda(subtotal)}</span></div>
    <div class="linea-resumen-pedido"><span>Impuestos</span><span>${formatearMoneda(impuestos)}</span></div>
    <div class="linea-resumen-pedido linea-resumen-pedido--total"><span>Total estimado</span><span>${formatearMoneda(total)}</span></div>
  `;
}

botonPagar.addEventListener("click", () => {
  if (itemsCarrito.length === 0) return;
  cerrarPanelCarrito();
  limpiarMensaje(mensajeCheckout);
  renderizarResumenPedido(resumenPedidoModal);
  abrirModal(modalCheckout);
});

cerrarCheckoutBtn.addEventListener("click", () => cerrarModal(modalCheckout));

function agregarDetalleConfirmacion(etiqueta, valor) {
  const linea = document.createElement("div");
  linea.className = "confirmacion__detalle-linea";
  const nombre = document.createElement("span");
  nombre.textContent = etiqueta;
  const contenido = document.createElement("span");
  contenido.textContent = valor;
  linea.append(nombre, contenido);
  detalleConfirmacion.appendChild(linea);
}

function validarRespuestaPedido(pedido) {
  return pedido
    && typeof pedido.numero === "string"
    && /^BF-\d{6,}$/.test(pedido.numero)
    && pedido.estado === "pendiente_pago"
    && Number.isFinite(Number(pedido.subtotal))
    && Number.isFinite(Number(pedido.impuestos))
    && Number.isFinite(Number(pedido.total))
    && Array.isArray(pedido.lineas);
}

formularioCheckout.addEventListener("submit", async (evento) => {
  evento.preventDefault();
  limpiarMensaje(mensajeCheckout);

  if (!supabase) {
    mostrarMensaje(mensajeCheckout, errorConfiguracionSupabase);
    return;
  }
  if (itemsCarrito.length === 0) {
    mostrarMensaje(mensajeCheckout, "Agregá al menos un equipo antes de confirmar.");
    return;
  }

  botonConfirmarPedido.disabled = true;
  botonConfirmarPedido.textContent = "Guardando pedido…";
  try {
    const { data: pedido, error } = await supabase.rpc("crear_pedido", {
      p_cliente: {
        nombre_cliente: document.getElementById("nombre-cliente").value,
        correo: document.getElementById("correo-cliente").value,
        telefono: document.getElementById("telefono-cliente").value,
        direccion: document.getElementById("direccion-envio").value,
        ciudad: document.getElementById("ciudad-envio").value,
        codigo_postal: document.getElementById("codigo-postal").value,
      },
      p_metodo_pago: metodoPagoSelect.value,
      p_items: itemsCarrito.map((item) => ({
        producto_id: item.producto.id,
        cantidad: item.cantidad,
      })),
    });

    if (error) throw new Error(`No se pudo guardar el pedido: ${error.message}`);
    if (!validarRespuestaPedido(pedido)) {
      throw new Error("El servidor no confirmó el pedido con un recibo válido.");
    }

    numeroOrdenSpan.textContent = pedido.numero;
    estadoPedidoSpan.textContent =
      "Pendiente de pago. No se procesó ningún cobro ni se envió un correo.";
    detalleConfirmacion.replaceChildren();
    const cantidadUnidades = pedido.lineas.reduce(
      (total, linea) => total + Number(linea.cantidad),
      0
    );
    agregarDetalleConfirmacion(
      "Envío a",
      `${document.getElementById("direccion-envio").value}, ${document.getElementById("ciudad-envio").value}`
    );
    agregarDetalleConfirmacion("Método de pago", metodoPagoSelect.value);
    agregarDetalleConfirmacion("Unidades", String(cantidadUnidades));
    agregarDetalleConfirmacion("Subtotal", formatearMoneda(Number(pedido.subtotal)));
    agregarDetalleConfirmacion("Impuestos", formatearMoneda(Number(pedido.impuestos)));
    agregarDetalleConfirmacion("Total pendiente", formatearMoneda(Number(pedido.total)));

    cerrarModal(modalCheckout);
    vaciarCarrito();
    renderizarCarrito();
    formularioCheckout.reset();
    abrirModal(modalConfirmacion);
  } catch (error) {
    mostrarMensaje(mensajeCheckout, error.message);
  } finally {
    botonConfirmarPedido.disabled = false;
    botonConfirmarPedido.textContent = "Confirmar pedido";
  }
});

cerrarConfirmacionBtn.addEventListener("click", () => cerrarModal(modalConfirmacion));

document.addEventListener("keydown", (evento) => {
  if (evento.key !== "Escape") return;
  cerrarPanelCarrito();
  cerrarModal(modalCheckout);
  cerrarModal(modalConfirmacion);
});

async function inicializarAplicacion() {
  await cargarCatalogo();
  renderizarCarrito();
}

inicializarAplicacion();
