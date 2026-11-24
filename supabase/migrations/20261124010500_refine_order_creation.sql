create or replace function public.crear_pedido(
  p_cliente jsonb,
  p_metodo_pago text,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_producto_id uuid;
  v_cantidad numeric;
  v_precio numeric(12, 2);
  v_subtotal numeric(12, 2) := 0;
  v_impuestos numeric(12, 2);
  v_total numeric(12, 2);
  v_tasa numeric(5, 4);
  v_pedido_id uuid;
  v_numero bigint;
begin
  if p_cliente is null or jsonb_typeof(p_cliente) <> 'object'
     or (p_cliente - array['nombre_cliente', 'correo', 'telefono', 'direccion', 'ciudad', 'codigo_postal']) <> '{}'::jsonb then
    raise exception 'Datos de cliente inválidos' using errcode = '22023';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'Los productos deben enviarse como una lista' using errcode = '22023';
  end if;

  if jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 12 then
    raise exception 'El pedido debe contener entre 1 y 12 productos' using errcode = '22023';
  end if;

  if p_metodo_pago is null or p_metodo_pago not in (
    'Tarjeta de crédito',
    'Tarjeta de débito',
    'Transferencia bancaria',
    'Pago contra entrega'
  ) then
    raise exception 'Método de pago inválido' using errcode = '22023';
  end if;

  if nullif(btrim(p_cliente ->> 'nombre_cliente'), '') is null
     or char_length(btrim(p_cliente ->> 'nombre_cliente')) > 60
     or nullif(btrim(p_cliente ->> 'correo'), '') is null
     or char_length(btrim(p_cliente ->> 'correo')) > 254
     or (p_cliente ->> 'correo') !~* '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
     or nullif(btrim(p_cliente ->> 'telefono'), '') is null
     or char_length(btrim(p_cliente ->> 'telefono')) > 32
     or nullif(btrim(p_cliente ->> 'direccion'), '') is null
     or char_length(btrim(p_cliente ->> 'direccion')) > 300
     or nullif(btrim(p_cliente ->> 'ciudad'), '') is null
     or char_length(btrim(p_cliente ->> 'ciudad')) > 80
     or char_length(coalesce(p_cliente ->> 'codigo_postal', '')) > 10 then
    raise exception 'Los datos de contacto o envío son inválidos' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_items) as entries(value)
    where jsonb_typeof(entries.value) <> 'object'
       or entries.value - array['producto_id', 'cantidad'] <> '{}'::jsonb
       or not (entries.value ? 'producto_id' and entries.value ? 'cantidad')
       or jsonb_typeof(entries.value -> 'producto_id') <> 'string'
       or jsonb_typeof(entries.value -> 'cantidad') <> 'number'
  ) then
    raise exception 'Hay productos con formato inválido' using errcode = '22023';
  end if;

  if (
    select count(distinct entries.value ->> 'producto_id') <> count(*)
    from jsonb_array_elements(p_items) as entries(value)
  ) then
    raise exception 'No se puede repetir un producto en el pedido' using errcode = '22023';
  end if;

  select tasa_impuesto
  into v_tasa
  from public.configuracion
  where id = true;

  if v_tasa is null then
    raise exception 'No hay una tasa de impuesto configurada';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_producto_id := (v_item ->> 'producto_id')::uuid;
    v_cantidad := (v_item ->> 'cantidad')::numeric;

    if v_cantidad <> trunc(v_cantidad) or v_cantidad < 1 or v_cantidad > 10 then
      raise exception 'La cantidad por producto debe ser un entero de 1 a 10' using errcode = '22023';
    end if;

    select precio
    into v_precio
    from public.productos
    where id = v_producto_id and activo = true
    for share;

    if not found then
      raise exception 'Un producto no existe o ya no está disponible' using errcode = '22023';
    end if;

    v_subtotal := v_subtotal + v_precio * v_cantidad;
  end loop;

  v_subtotal := round(v_subtotal, 2);
  v_impuestos := round(v_subtotal * v_tasa, 2);
  v_total := v_subtotal + v_impuestos;

  insert into public.pedidos (
    cliente_id,
    nombre_cliente,
    correo,
    telefono,
    direccion,
    ciudad,
    codigo_postal,
    metodo_pago,
    estado,
    subtotal,
    impuestos,
    total,
    tasa_impuesto
  )
  values (
    auth.uid(),
    btrim(p_cliente ->> 'nombre_cliente'),
    btrim(p_cliente ->> 'correo'),
    btrim(p_cliente ->> 'telefono'),
    btrim(p_cliente ->> 'direccion'),
    btrim(p_cliente ->> 'ciudad'),
    nullif(btrim(coalesce(p_cliente ->> 'codigo_postal', '')), ''),
    p_metodo_pago,
    'pendiente_pago',
    v_subtotal,
    v_impuestos,
    v_total,
    v_tasa
  )
  returning id, numero into v_pedido_id, v_numero;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_producto_id := (v_item ->> 'producto_id')::uuid;
    v_cantidad := (v_item ->> 'cantidad')::numeric;

    select precio
    into v_precio
    from public.productos
    where id = v_producto_id and activo = true;

    insert into public.lineas_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    values (v_pedido_id, v_producto_id, v_cantidad::integer, v_precio, v_precio * v_cantidad);
  end loop;

  return jsonb_build_object(
    'numero', 'BF-' || lpad(v_numero::text, 6, '0'),
    'estado', 'pendiente_pago',
    'subtotal', v_subtotal,
    'impuestos', v_impuestos,
    'total', v_total,
    'lineas', (
      select jsonb_agg(jsonb_build_object(
        'nombre', productos.nombre,
        'cantidad', lineas_pedido.cantidad,
        'precio_unitario', lineas_pedido.precio_unitario,
        'subtotal', lineas_pedido.subtotal
      ) order by productos.nombre)
      from public.lineas_pedido
      join public.productos on productos.id = lineas_pedido.producto_id
      where lineas_pedido.pedido_id = v_pedido_id
    )
  );
end;
$$;
