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
