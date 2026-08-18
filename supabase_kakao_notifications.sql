-- =============================================================
-- Supabase KakaoTalk Alimtalk Webhook & Trigger Setup SQL
-- 카카오 알림톡 자동 발송 Supabase DB 트리거 및 Webhook 연동 설정
-- =============================================================

-- 1. Enable `pg_net` extension for HTTP request calls from Postgres
create extension if not exists pg_net;

-- 2. Function to trigger Kakao Alimtalk Webhook on Order Status Update
create or replace function public.trigger_kakao_alimtalk_on_status_change()
returns trigger
language plpgsql
security definer
as $$
declare
  webhook_url text := 'https://your-supabase-project.supabase.co/functions/v1/send-kakao-alimtalk'; -- Supabase Edge Function URL
  payload jsonb;
begin
  -- Only trigger when order status changes and customer phone exists
  if (OLD.status is null or OLD.status <> NEW.status) and (NEW.user_phone is not null and NEW.user_phone <> '') then
    
    payload := jsonb_build_object(
      'order_id', NEW.id,
      'order_number', NEW.order_number,
      'store_id', NEW.store_id,
      'user_name', NEW.user_name,
      'user_phone', NEW.user_phone,
      'status', NEW.status,
      'total_amount', NEW.total_amount,
      'updated_at', NEW.updated_at
    );

    -- Perform asynchronous HTTP POST request using pg_net
    perform net.http_post(
      url := webhook_url,
      headers := '{"Content-Type": "application/json"}'::jsonb,
      body := payload
    );
    
  end if;
  return NEW;
end;
$$;

-- 3. Create Trigger on `public.orders` table
drop trigger if exists trg_kakao_alimtalk_order_status on public.orders;

create trigger trg_kakao_alimtalk_order_status
  after update of status on public.orders
  for each row
  execute function public.trigger_kakao_alimtalk_on_status_change();

-- =============================================================
-- Solapi / NHN Cloud Alimtalk Edge Function Template (Deno/TS)
-- Place this code in `supabase/functions/send-kakao-alimtalk/index.ts`
-- =============================================================
/*
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { order_number, user_phone, status, user_name } = await req.json();

  let message = "";
  if (status === "preparing") {
    message = `[주문 접수 완료]\n${user_name}님, 주문(${order_number})이 접수되어 메뉴 조리가 시작되었습니다.`;
  } else if (status === "ready") {
    message = `[메뉴 준비 완료]\n${user_name}님, 주문(${order_number})이 준비되었습니다. 카운터에서 픽업해 주세요!`;
  } else if (status === "cancelled") {
    message = `[주문 취소 안내]\n${user_name}님, 주문(${order_number})이 취소되었습니다.`;
  }

  // Solapi / NHN Cloud Kakao Alimtalk REST API call
  // const SOLAPI_API_KEY = Deno.env.get("SOLAPI_API_KEY");
  // const SOLAPI_SECRET_KEY = Deno.env.get("SOLAPI_SECRET_KEY");
  // ... execute API request

  return new Response(JSON.stringify({ success: true, message }), {
    headers: { "Content-Type": "application/json" },
  });
})
*/
