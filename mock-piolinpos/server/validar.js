/**
 * Único lugar donde se valida el pedido y se calculan precios/total — ni el
 * parser de reglas ni el LLM tienen la última palabra sobre esto.
 */
export function validarPedido(pedido, catalogo) {
  const lineas = (pedido.lineas ?? []).map((linea) => validarLinea(linea, catalogo));
  const no_reconocidos = pedido.no_reconocidos ?? [];
  const total = lineas.reduce((sum, l) => sum + (l.error ? 0 : l.subtotal), 0);

  return { lineas, no_reconocidos, total };
}

function validarLinea(linea, catalogo) {
  const producto = catalogo.find((p) => p.id === linea.id_producto);
  const cantidadCruda = linea.cantidad;
  const cantidad = Number.isInteger(cantidadCruda) ? cantidadCruda : Math.round(cantidadCruda ?? 1);

  const base = {
    id_producto: linea.id_producto ?? null,
    cantidad,
    selecciones: linea.selecciones ?? { ingredientes: [], modo: null },
    quitar: linea.quitar ?? [],
    fragmento: linea.fragmento ?? "",
    modo_por_defecto: false,
    incompleta: false,
    error: false,
    unitPrice: 0,
    subtotal: 0,
  };

  // Regla: el id debe existir en el catálogo.
  if (!producto) return { ...base, error: true };

  // Regla: cantidad entera entre 1 y 50.
  if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > 50) {
    return { ...base, error: true };
  }

  if (producto.categoria === "super_torta") {
    const ingredientes = (linea.selecciones?.ingredientes ?? []).filter((i) =>
      producto.ingredientesPermitidos.includes(i),
    );

    // Regla: Super Torta debe tener EXACTAMENTE 2 ingredientes válidos.
    if (ingredientes.length !== 2) {
      return { ...base, error: true, unitPrice: producto.precio };
    }

    const modoDicho = linea.selecciones?.modo;
    const modoValido = modoDicho && producto.modos.includes(modoDicho);
    const modo = modoValido ? modoDicho : producto.modoDefault;

    return {
      ...base,
      selecciones: { ingredientes, modo },
      modo_por_defecto: !modoValido,
      unitPrice: producto.precio,
      subtotal: producto.precio * cantidad,
    };
  }

  return {
    ...base,
    unitPrice: producto.precio,
    subtotal: producto.precio * cantidad,
  };
}
