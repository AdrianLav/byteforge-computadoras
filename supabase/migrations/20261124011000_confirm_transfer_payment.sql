create function public.confirmar_transferencia(
  p_numero bigint,
  p_referencia varchar(64)
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_pedido public.pedidos%rowtype;
begin
  if coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '') not in ('ventas', 'admin') then
    raise exception 'Se requiere el rol ventas o admin' using errcode = '42501';
  end if;

  if p_referencia is null or nullif(btrim(p_referencia), '') is null or char_length(btrim(p_referencia)) > 64 then
    raise exception 'La referencia de transferencia debe contener entre 1 y 64 caracteres' using errcode = '22023';
  end if;

  select *
  into v_pedido
  from public.pedidos
  where numero = p_numero and activo = true
  for update;

  if not found
     or v_pedido.estado <> 'pendiente_pago'
     or v_pedido.metodo_pago <> 'Transferencia bancaria' then
    raise exception 'El pedido no está pendiente de una transferencia válida' using errcode = '22023';
  end if;

  insert into public.pagos (pedido_id, proveedor, referencia_pago, estado, importe)
  values (v_pedido.id, 'transferencia', btrim(p_referencia), 'confirmado', v_pedido.total);

  update public.pedidos
  set estado = 'pagado',
      referencia_pago = btrim(p_referencia)
  where id = v_pedido.id;
end;
$$;

revoke all on function public.confirmar_transferencia(bigint, varchar) from public, anon, authenticated;
grant execute on function public.confirmar_transferencia(bigint, varchar) to authenticated;
