insert into public.productos (
  id, nombre, tipo, categoria, procesador, ram, almacenamiento, tarjeta_grafica, precio, imagen
)
values
  ('00000000-0000-4000-8000-000000000001', 'ForgeStrike RTX', 'PC de Escritorio', 'Gamer', 'Intel Core i7-14700K', '32 GB DDR5', '1 TB SSD NVMe', 'NVIDIA RTX 4070 Ti', 7900.00, 'https://images.unsplash.com/photo-1587202372775-e229f172b9d7?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000002', 'Vortex 15 Gamer', 'Laptop Gamer', 'Gamer', 'AMD Ryzen 7 8845HS', '16 GB DDR5', '512 GB SSD NVMe', 'NVIDIA RTX 4060 (8GB)', 6200.00, 'https://images.unsplash.com/photo-1603302576837-37561b2e2302?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000003', 'Overclock X9 Extreme', 'PC de Escritorio', 'Gamer', 'Intel Core i9-14900K', '64 GB DDR5', '2 TB SSD NVMe', 'NVIDIA RTX 4090', 11500.00, 'https://images.unsplash.com/photo-1591405351990-4726e331f141?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000004', 'OfficeLine Compact', 'PC de Escritorio', 'Oficina', 'Intel Core i5-13400', '8 GB DDR4', '256 GB SSD', 'Gráficos integrados Intel UHD', 2490.00, 'https://images.unsplash.com/photo-1547082299-de196ea013d6?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000005', 'SlimBook Air 14', 'Laptop', 'Oficina', 'Intel Core i5-1335U', '8 GB LPDDR5', '512 GB SSD', 'Gráficos integrados Intel Iris Xe', 3290.00, 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000006', 'BizPro Ultrabook', 'Laptop', 'Oficina', 'AMD Ryzen 5 7530U', '16 GB DDR4', '512 GB SSD', 'Gráficos integrados AMD Radeon', 3790.00, 'https://images.unsplash.com/photo-1588872657578-7efd1f1555ed?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000007', 'TaskMaster Mini', 'Mini PC', 'Oficina', 'Intel Core i3-13100', '8 GB DDR4', '256 GB SSD', 'Gráficos integrados Intel UHD', 1990.00, 'https://images.unsplash.com/photo-1587831990711-23ca6441447b?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000008', 'WorkStation Titan Pro', 'PC de Escritorio', 'Trabajo Pesado', 'AMD Threadripper 7960X', '128 GB DDR5 ECC', '4 TB SSD NVMe', 'NVIDIA RTX 6000 Ada', 16900.00, 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000009', 'RenderMax Studio', 'PC de Escritorio', 'Trabajo Pesado', 'Intel Xeon W-2495X', '64 GB DDR5 ECC', '2 TB SSD NVMe + 4 TB HDD', 'NVIDIA RTX 4080', 12900.00, 'https://images.unsplash.com/photo-1560732488-6b0df240254a?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000010', 'MobileWorks 16 Pro', 'Laptop', 'Trabajo Pesado', 'Intel Core i9-13950HX', '32 GB DDR5', '1 TB SSD NVMe', 'NVIDIA RTX 4000 Ada (Laptop)', 9800.00, 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000011', 'CreatorEdge 15', 'Laptop', 'Trabajo Pesado', 'AMD Ryzen 9 7945HX', '32 GB DDR5', '1 TB SSD NVMe', 'NVIDIA RTX 4070 (Laptop)', 8400.00, 'https://images.unsplash.com/photo-1523475496153-3d6cc0f0bf19?w=600&h=450&fit=crop'),
  ('00000000-0000-4000-8000-000000000012', 'PulseFrame 5 Gamer', 'PC de Escritorio', 'Gamer', 'AMD Ryzen 5 7600X', '16 GB DDR5', '1 TB SSD NVMe', 'AMD Radeon RX 7700 XT', 5200.00, 'https://images.unsplash.com/photo-1600861195091-690c92f1d2cd?w=600&h=450&fit=crop')
on conflict (id) do nothing;
