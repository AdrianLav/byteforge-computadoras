create or replace function public.cambiar_estado_pedido(p_numero bigint, p_estado text)
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
     and (v_pedido.estado = 'pagado'
       or (v_pedido.estado = 'pendiente_pago' and v_pedido.metodo_pago = 'Pago contra entrega'))
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
    if v_pedido.metodo_pago = 'Pago contra entrega' then
      insert into public.pagos (pedido_id, proveedor, referencia_pago, estado, importe)
      values (
        v_pedido.id,
        'contra_entrega',
        'COD-BF-' || v_pedido.numero::text,
        'confirmado',
        v_pedido.total
      );
    end if;
    update public.pedidos set estado = p_estado where id = v_pedido.id;
    return;
  end if;

  raise exception 'Transición de estado no permitida' using errcode = '42501';
end;
$$;
