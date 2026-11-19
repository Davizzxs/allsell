-- ALLSELL · Esquema para Supabase (SQL Editor > New query > Run)

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  created_at timestamptz default now()
);

create table public.categories (
  id serial primary key,
  name text unique not null
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  category_id int references public.categories(id),
  name text not null,
  description text default '',
  price numeric(12,2) not null check (price > 0),
  old_price numeric(12,2),
  image_url text,
  badge text check (badge in ('nuevo','oferta','mas_vendido')),
  created_at timestamptz default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  buyer_id uuid not null default auth.uid() references public.profiles(id),
  total numeric(12,2) not null,
  created_at timestamptz default now()
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  name text not null,
  price numeric(12,2) not null,
  qty int not null check (qty > 0)
);

insert into public.categories(name) values
('Tecnología'),('Ropa y accesorios'),('Hogar'),('Deportes'),('Belleza'),('Juguetes'),('Otros');

-- Crear perfil automáticamente al registrarse
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, name)
  values (new.id, coalesce(new.raw_user_meta_data->>'name',''));
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- SEGURIDAD: Row Level Security
alter table public.profiles    enable row level security;
alter table public.categories  enable row level security;
alter table public.products    enable row level security;
alter table public.orders      enable row level security;
alter table public.order_items enable row level security;

create policy "perfiles visibles"  on public.profiles   for select using (true);
create policy "editar mi perfil"   on public.profiles   for update using (auth.uid() = id);
create policy "categorias visibles" on public.categories for select using (true);

create policy "productos visibles"   on public.products for select using (true);
create policy "vendedor crea"        on public.products for insert with check (auth.uid() = seller_id);
create policy "vendedor edita lo suyo"  on public.products for update using (auth.uid() = seller_id) with check (auth.uid() = seller_id);
create policy "vendedor elimina lo suyo" on public.products for delete using (auth.uid() = seller_id);

create policy "ver mis pedidos"  on public.orders for select using (auth.uid() = buyer_id);
create policy "crear mi pedido"  on public.orders for insert with check (auth.uid() = buyer_id);

create policy "ver mis detalles" on public.order_items for select
  using (exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid()));
create policy "crear mis detalles" on public.order_items for insert
  with check (exists (select 1 from public.orders o where o.id = order_id and o.buyer_id = auth.uid()));

-- Almacenamiento de imágenes de productos
insert into storage.buckets (id, name, public) values ('product-images','product-images', true)
on conflict do nothing;

create policy "imagenes publicas" on storage.objects for select using (bucket_id = 'product-images');
create policy "subir a mi carpeta" on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "borrar de mi carpeta" on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and (storage.foldername(name))[1] = auth.uid()::text);
