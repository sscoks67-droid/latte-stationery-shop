-- ============================================================
--  라떼 문구점 - 장바구니 저장용 테이블
--  Supabase 대시보드 > SQL Editor 에 붙여넣고 Run 을 누르세요.
--  ※ 이 SQL 은 2026-10-10 에 이미 실행되었습니다. (테이블 생성 완료)
-- ============================================================

-- 1) 장바구니 테이블 만들기
create table if not exists public.carts (
  id         text primary key,                        -- 손님마다 하나씩 받는 장바구니 번호
  items      jsonb not null default '[]'::jsonb,      -- 담은 상품 목록
  updated_at timestamptz not null default now()       -- 마지막으로 바뀐 시각
);

-- 2) 행 수준 보안(RLS) 켜기  ★ 반드시 켜야 합니다
alter table public.carts enable row level security;

-- 3) 사이트(공개 키)가 장바구니를 읽고 쓸 수 있게 허용
drop policy if exists cart_read   on public.carts;
drop policy if exists cart_insert on public.carts;
drop policy if exists cart_update on public.carts;

create policy cart_read   on public.carts for select to anon using (true);
create policy cart_insert on public.carts for insert to anon with check (true);
create policy cart_update on public.carts for update to anon using (true) with check (true);

-- 삭제는 허용하지 않습니다 (실수로 지워지는 것을 막기 위해)

-- ============================================================
--  ※ 알아두실 점
--  위 정책은 "공개 키를 가진 사람은 장바구니를 읽고 쓸 수 있다" 는 뜻입니다.
--  장바구니에는 상품 이름과 개수만 들어가므로 개인정보는 없지만,
--  더 엄격하게 막고 싶으면 Supabase 의 익명 로그인(Anonymous sign-in)을 켜고
--  정책을 auth.uid() 기준으로 바꾸면 됩니다.
-- ============================================================


-- ============================================================
--  상품 목록 테이블  (2026-10-10 실행 완료, 상품 19개 저장됨)
-- ============================================================

create table if not exists public.products (
  id          int primary key,                 -- 상품 번호 (화면에 보이는 순서)
  name        text not null unique,            -- 상품 이름
  price       int not null,                    -- 파는 값
  old_price   int,                             -- 할인 전 값
  category    text not null,                   -- pen / paper / art / etc
  discount    int,                             -- 할인율 (%)
  is_best     boolean not null default false,  -- BEST 표시 여부
  image       text,                            -- 사진 파일 경로
  sort_order  int,                             -- 보여줄 순서
  created_at  timestamptz not null default now()
);

-- 누구나 볼 수 있지만, 바꾸는 것은 주인만 (대시보드에서)
alter table public.products enable row level security;

drop policy if exists product_read on public.products;
create policy product_read on public.products for select to anon using (true);

-- 상품을 추가하거나 값을 바꾸려면 대시보드 SQL Editor 에서 아래처럼 하세요.
--   update public.products set price = 3200 where name = '파스텔 연필 세트';
--   insert into public.products (id, name, price, old_price, category, discount, image, sort_order)
--   values (20, '새 상품 이름', 5000, 6000, 'etc', 17, 'images/new.jpg', 20);


-- ============================================================
--  장바구니 표  (2026-10-10 실행 완료)
--  예전에는 carts 표에 JSON 덩어리로 넣었지만,
--  이제 담은 상품을 한 줄씩 넣고 상품표와 연결합니다.
-- ============================================================

create table if not exists public.cart_items (
  cart_id    text not null,                                       -- 손님(또는 계정) 장바구니 번호
  product_id int  not null references public.products(id) on delete cascade,
  count      int  not null default 1 check (count > 0),           -- 담은 개수
  updated_at timestamptz not null default now(),
  primary key (cart_id, product_id)
);

alter table public.cart_items enable row level security;

drop policy if exists ci_read   on public.cart_items;
drop policy if exists ci_insert on public.cart_items;
drop policy if exists ci_update on public.cart_items;
drop policy if exists ci_delete on public.cart_items;

create policy ci_read   on public.cart_items for select to anon using (true);
create policy ci_insert on public.cart_items for insert to anon with check (true);
create policy ci_update on public.cart_items for update to anon using (true) with check (true);
create policy ci_delete on public.cart_items for delete to anon using (true);

-- 누가 무엇을 담았는지 한눈에 보기
--   select ci.cart_id, p.name, ci.count, p.price * ci.count as amount
--   from public.cart_items ci join public.products p on p.id = ci.product_id
--   order by ci.cart_id, p.id;

-- ※ 옛 carts 표는 이제 쓰지 않습니다. 지우려면:  drop table public.carts;


-- ============================================================
--  찜한 상품 표  (2026-10-10 실행 완료)
--  owner_id 는 장바구니 번호와 같은 값입니다.
--  (로그인 전에는 cart-..., 로그인하면 user-... )
-- ============================================================

create table if not exists public.wish_items (
  owner_id   text not null,
  product_id int  not null references public.products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (owner_id, product_id)
);

alter table public.wish_items enable row level security;

drop policy if exists wi_read   on public.wish_items;
drop policy if exists wi_insert on public.wish_items;
drop policy if exists wi_delete on public.wish_items;

create policy wi_read   on public.wish_items for select to anon using (true);
create policy wi_insert on public.wish_items for insert to anon with check (true);
create policy wi_delete on public.wish_items for delete to anon using (true);

-- 어떤 상품이 가장 많이 찜 받았는지 보기
--   select p.name, count(*) as 찜수
--   from public.wish_items w join public.products p on p.id = w.product_id
--   group by p.name order by 찜수 desc;


-- ============================================================
--  주문 표  (2026-10-10 실행 완료)
--  ★ 주문서에는 이름·연락처·주소 같은 개인정보가 들어갑니다.
--    그래서 공개 키로는 읽지도 쓰지도 못하게 막고,
--    로그인한 본인만 자기 주문을 저장·조회할 수 있게 했습니다.
-- ============================================================

create table if not exists public.orders (
  id            uuid primary key default gen_random_uuid(),   -- 주문번호
  user_id       uuid not null references auth.users(id) on delete cascade,
  receiver_name text not null,      -- 받는 사람 이름
  receiver_tel  text not null,      -- 연락처
  address       text not null,      -- 주소 (한 칸에 전부)
  items_total   int  not null,      -- 상품 총금액
  shipping_fee  int  not null,      -- 배송비
  pay_total     int  not null,      -- 전체 합계 금액
  status        text not null default '접수',
  created_at    timestamptz not null default now()
);

create table if not exists public.order_items (
  order_id   uuid not null references public.orders(id) on delete cascade,
  product_id int  not null references public.products(id),
  name       text not null,         -- 주문 당시의 상품 이름
  price      int  not null,         -- 주문 당시의 값 (나중에 값이 바뀌어도 그대로)
  count      int  not null check (count > 0),
  primary key (order_id, product_id)
);

alter table public.orders      enable row level security;
alter table public.order_items enable row level security;

drop policy if exists o_read   on public.orders;
drop policy if exists o_insert on public.orders;
drop policy if exists oi_read   on public.order_items;
drop policy if exists oi_insert on public.order_items;

-- 로그인한 본인 주문만
create policy o_read   on public.orders for select to authenticated using (user_id = auth.uid());
create policy o_insert on public.orders for insert to authenticated with check (user_id = auth.uid());

create policy oi_read on public.order_items for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()));
create policy oi_insert on public.order_items for insert to authenticated
  with check (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()));

-- 가게 주인이 주문을 보려면 대시보드에서 (대시보드는 RLS 를 넘어 볼 수 있습니다)
--   select o.created_at, o.receiver_name, o.receiver_tel, o.address, o.pay_total,
--          string_agg(i.name || ' ' || i.count || '개', ', ') as 상품
--   from public.orders o join public.order_items i on i.order_id = o.id
--   group by o.id order by o.created_at desc;
