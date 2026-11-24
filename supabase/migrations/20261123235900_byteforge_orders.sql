create table public.productos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  tipo text not null,
  categoria text not null,
  procesador text not null,
  ram text not null,
  almacenamiento text not null,
  tarjeta_grafica text not null,
  precio numeric(12, 2) not null check (precio >= 0),
  imagen text not null,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  modificado_en timestamptz not null default now()
);

create table public.configuracion (
  id boolean primary key default true check (id),
  tasa_impuesto numeric(5, 4) not null check (tasa_impuesto >= 0 and tasa_impuesto <= 1),
  modificado_en timestamptz not null default now()
);

insert into public.configuracion (id, tasa_impuesto)
values (true, 0.16)
on conflict (id) do nothing;

create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  numero bigint generated always as identity unique,
  cliente_id uuid references auth.users (id) on delete set null,
  nombre_cliente varchar(60) not null,
  correo varchar(254) not null,
  telefono varchar(32) not null,
  direccion varchar(300) not null,
  ciudad varchar(80) not null,
  codigo_postal varchar(10),
  metodo_pago text not null check (
    metodo_pago in (
      'Tarjeta de crédito',
      'Tarjeta de débito',
      'Transferencia bancaria',
      'Pago contra entrega'
    )
  ),
  estado text not null default 'pendiente_pago' check (
    estado in ('pendiente_pago', 'pagado', 'preparando', 'enviado', 'entregado', 'cancelado')
  ),
  activo boolean not null default true,
  referencia_pago varchar(64),
  subtotal numeric(12, 2) not null check (subtotal >= 0),
  impuestos numeric(12, 2) not null check (impuestos >= 0),
  total numeric(12, 2) not null check (total = subtotal + impuestos),
  tasa_impuesto numeric(5, 4) not null check (tasa_impuesto >= 0 and tasa_impuesto <= 1),
  creado_en timestamptz not null default now(),
  modificado_en timestamptz not null default now()
);

create table public.lineas_pedido (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete restrict,
  producto_id uuid not null references public.productos (id) on delete restrict,
  cantidad integer not null check (cantidad between 1 and 10),
  precio_unitario numeric(12, 2) not null check (precio_unitario >= 0),
  subtotal numeric(12, 2) not null check (subtotal = precio_unitario * cantidad),
  creado_en timestamptz not null default now(),
  unique (pedido_id, producto_id)
);

create table public.pagos (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos (id) on delete restrict,
  proveedor text not null,
  referencia_pago varchar(64) not null unique,
  estado text not null check (estado in ('pendiente', 'confirmado', 'rechazado', 'reembolsado')),
  importe numeric(12, 2) not null check (importe >= 0),
  creado_en timestamptz not null default now()
);

create index lineas_pedido_pedido_id_idx on public.lineas_pedido (pedido_id);
create index lineas_pedido_producto_id_idx on public.lineas_pedido (producto_id);
create index pedidos_estado_activo_idx on public.pedidos (estado, activo);
create index pagos_pedido_id_idx on public.pagos (pedido_id);

create function public.actualizar_modificado_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.modificado_en := now();
  return new;
end;
$$;

create trigger productos_actualizar_modificado_en
before update on public.productos
for each row execute function public.actualizar_modificado_en();

create trigger configuracion_actualizar_modificado_en
before update on public.configuracion
for each row execute function public.actualizar_modificado_en();

create trigger pedidos_actualizar_modificado_en
before update on public.pedidos
for each row execute function public.actualizar_modificado_en();

create function public.es_personal_byteforge()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') in ('ventas', 'despacho', 'admin');
$$;

alter table public.productos enable row level security;
alter table public.configuracion enable row level security;
alter table public.pedidos enable row level security;
alter table public.lineas_pedido enable row level security;
alter table public.pagos enable row level security;

create policy "Lectura de productos activos o para personal"
on public.productos for select
to anon, authenticated
using (activo or public.es_personal_byteforge());

create policy "Administradores crean productos"
on public.productos for insert
to authenticated
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Administradores actualizan productos"
on public.productos for update
to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Lectura pública de la tasa"
on public.configuracion for select
to anon, authenticated
using (true);

create policy "Administradores crean configuración"
on public.configuracion for insert
to authenticated
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Administradores actualizan configuración"
on public.configuracion for update
to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
with check ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

create policy "Personal autorizado lee pedidos"
on public.pedidos for select
to authenticated
using (
  public.es_personal_byteforge()
  and (activo or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin')
);

create policy "Personal autorizado lee líneas"
on public.lineas_pedido for select
to authenticated
using (
  exists (
    select 1
    from public.pedidos
    where pedidos.id = lineas_pedido.pedido_id
      and public.es_personal_byteforge()
      and (
        pedidos.activo
        or (auth.jwt() -> 'app_metadata' ->> 'role') = 'admin'
      )
  )
);

create policy "Solo administradores leen pagos"
on public.pagos for select
to authenticated
using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

grant select on public.productos, public.configuracion to anon, authenticated;
revoke insert, update on public.productos, public.configuracion from authenticated;
grant insert (nombre, tipo, categoria, procesador, ram, almacenamiento, tarjeta_grafica, precio, imagen, activo)
on public.productos to authenticated;
grant update (nombre, tipo, categoria, procesador, ram, almacenamiento, tarjeta_grafica, precio, imagen, activo)
on public.productos to authenticated;
grant insert (tasa_impuesto) on public.configuracion to authenticated;
grant update (tasa_impuesto) on public.configuracion to authenticated;
grant select on public.pedidos, public.lineas_pedido, public.pagos to authenticated;
revoke all on public.pedidos, public.lineas_pedido, public.pagos from anon;
revoke insert, update, delete on public.pedidos, public.lineas_pedido, public.pagos from anon, authenticated;
revoke delete on public.productos, public.configuracion from anon, authenticated;

create function public.crear_pedido(
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
  v_nombre text;
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

    select nombre, precio
    into v_nombre, v_precio
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

revoke all on function public.crear_pedido(jsonb, text, jsonb) from public, anon, authenticated;
grant execute on function public.crear_pedido(jsonb, text, jsonb) to anon, authenticated;
grant execute on function public.es_personal_byteforge() to anon, authenticated;

create function public.actualizar_pedido_pendiente(
  p_numero bigint,
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
  v_pedido public.pedidos%rowtype;
  v_item jsonb;
  v_normalized jsonb := '[]'::jsonb;
  v_producto_id uuid;
  v_cantidad numeric;
  v_precio numeric(12, 2);
  v_precio_actual numeric(12, 2);
  v_subtotal numeric(12, 2) := 0;
  v_impuestos numeric(12, 2);
  v_total numeric(12, 2);
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') not in ('ventas', 'admin') then
    raise exception 'Se requiere el rol ventas o admin' using errcode = '42501';
  end if;

  if p_cliente is null or jsonb_typeof(p_cliente) <> 'object'
     or (p_cliente - array['nombre_cliente', 'correo', 'telefono', 'direccion', 'ciudad', 'codigo_postal']) <> '{}'::jsonb then
    raise exception 'Datos de cliente inválidos' using errcode = '22023';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) < 1 or jsonb_array_length(p_items) > 12 then
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

  select *
  into v_pedido
  from public.pedidos
  where numero = p_numero and activo = true
  for update;
  if not found or v_pedido.estado <> 'pendiente_pago' then
    raise exception 'Solo se pueden modificar pedidos activos pendientes de pago' using errcode = '22023';
  end if;

  for v_item in select value from jsonb_array_elements(p_items)
  loop
    v_producto_id := (v_item ->> 'producto_id')::uuid;
    v_cantidad := (v_item ->> 'cantidad')::numeric;
    if v_cantidad <> trunc(v_cantidad) or v_cantidad < 1 or v_cantidad > 10 then
      raise exception 'La cantidad por producto debe ser un entero de 1 a 10' using errcode = '22023';
    end if;

    select precio
    into v_precio_actual
    from public.productos
    where id = v_producto_id and activo = true
    for share;
    if not found then
      raise exception 'Un producto no existe o ya no está disponible' using errcode = '22023';
    end if;

    select precio_unitario
    into v_precio
    from public.lineas_pedido
    where pedido_id = v_pedido.id and producto_id = v_producto_id;
    if not found then
      v_precio := v_precio_actual;
    end if;

    v_subtotal := v_subtotal + v_precio * v_cantidad;
    v_normalized := v_normalized || jsonb_build_array(jsonb_build_object(
      'producto_id', v_producto_id,
      'cantidad', v_cantidad::integer,
      'precio_unitario', v_precio
    ));
  end loop;

  v_subtotal := round(v_subtotal, 2);
  v_impuestos := round(v_subtotal * v_pedido.tasa_impuesto, 2);
  v_total := v_subtotal + v_impuestos;

  update public.pedidos
  set nombre_cliente = btrim(p_cliente ->> 'nombre_cliente'),
      correo = btrim(p_cliente ->> 'correo'),
      telefono = btrim(p_cliente ->> 'telefono'),
      direccion = btrim(p_cliente ->> 'direccion'),
      ciudad = btrim(p_cliente ->> 'ciudad'),
      codigo_postal = nullif(btrim(coalesce(p_cliente ->> 'codigo_postal', '')), ''),
      metodo_pago = p_metodo_pago,
      subtotal = v_subtotal,
      impuestos = v_impuestos,
      total = v_total
  where id = v_pedido.id;

  delete from public.lineas_pedido where pedido_id = v_pedido.id;
  for v_item in select value from jsonb_array_elements(v_normalized)
  loop
    insert into public.lineas_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
    values (
      v_pedido.id,
      (v_item ->> 'producto_id')::uuid,
      (v_item ->> 'cantidad')::integer,
      (v_item ->> 'precio_unitario')::numeric,
      (v_item ->> 'precio_unitario')::numeric * (v_item ->> 'cantidad')::integer
    );
  end loop;

  return jsonb_build_object(
    'numero', 'BF-' || lpad(v_pedido.numero::text, 6, '0'),
    'estado', v_pedido.estado,
    'subtotal', v_subtotal,
    'impuestos', v_impuestos,
    'total', v_total
  );
end;
$$;

create function public.cambiar_estado_pedido(p_numero bigint, p_estado text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pedido public.pedidos%rowtype;
  v_rol text := coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '');
begin
  if v_rol not in ('ventas', 'despacho', 'admin') then
    raise exception 'Se requiere una cuenta de personal autorizada' using errcode = '42501';
  end if;

  select *
  into v_pedido
  from public.pedidos
  where numero = p_numero and activo = true
  for update;
  if not found then
    raise exception 'Pedido no encontrado' using errcode = '22023';
  end if;

  if p_estado = 'cancelado'
     and v_pedido.estado = 'pendiente_pago'
     and v_rol in ('ventas', 'admin') then
    update public.pedidos set estado = p_estado where id = v_pedido.id;
    return;
  end if;
  if p_estado = 'preparando'
     and v_pedido.estado = 'pagado'
     and v_rol in ('despacho', 'admin') then
    update public.pedidos set estado = p_estado where id = v_pedido.id;
    return;
  end if;
  if p_estado = 'enviado'
     and v_pedido.estado = 'preparando'
     and v_rol in ('despacho', 'admin') then
    update public.pedidos set estado = p_estado where id = v_pedido.id;
    return;
  end if;
  if p_estado = 'entregado'
     and v_pedido.estado = 'enviado'
     and v_rol in ('despacho', 'admin') then
    update public.pedidos set estado = p_estado where id = v_pedido.id;
    return;
  end if;

  raise exception 'Transición de estado no permitida' using errcode = '42501';
end;
$$;

create function public.desactivar_pedido(p_numero bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') <> 'admin' then
    raise exception 'Se requiere el rol admin' using errcode = '42501';
  end if;
  update public.pedidos
  set activo = false
  where numero = p_numero and activo = true;
  if not found then
    raise exception 'Pedido no encontrado o ya desactivado' using errcode = '22023';
  end if;
end;
$$;

create function public.anonimizar_pedido(p_numero bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') <> 'admin' then
    raise exception 'Se requiere el rol admin' using errcode = '42501';
  end if;

  update public.pedidos
  set nombre_cliente = 'Cliente anonimizado',
      correo = 'anonimo+' || id::text || '@invalid.local',
      telefono = '',
      direccion = '',
      ciudad = '',
      codigo_postal = null
  where numero = p_numero;

  if not found then
    raise exception 'Pedido no encontrado' using errcode = '22023';
  end if;
end;
$$;

revoke all on function public.actualizar_pedido_pendiente(bigint, jsonb, text, jsonb) from public, anon, authenticated;
revoke all on function public.cambiar_estado_pedido(bigint, text) from public, anon, authenticated;
revoke all on function public.desactivar_pedido(bigint) from public, anon, authenticated;
revoke all on function public.anonimizar_pedido(bigint) from public, anon, authenticated;
grant execute on function public.actualizar_pedido_pendiente(bigint, jsonb, text, jsonb) to authenticated;
grant execute on function public.cambiar_estado_pedido(bigint, text) to authenticated;
grant execute on function public.desactivar_pedido(bigint) to authenticated;
grant execute on function public.anonimizar_pedido(bigint) to authenticated;
