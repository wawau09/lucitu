create or replace function public.submit_store_rating(
  p_store_id text,
  p_drink numeric,
  p_hygiene numeric,
  p_atmosphere numeric,
  p_final numeric
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_reviews jsonb;
  v_updated_reviews jsonb;
  v_new_review jsonb;
begin
  if v_user_id is null then
    raise exception 'loginRequired';
  end if;

  select coalesce(reviews::jsonb, '[]'::jsonb)
    into v_reviews
    from public.stores
    where id::text = p_store_id
    for update;

  if not found then
    raise exception 'storeNotFound';
  end if;

  if exists (
    select 1
      from jsonb_array_elements(v_reviews) as review
      where review ->> 'user_id' = v_user_id::text
  ) then
    raise exception 'alreadyRated';
  end if;

  v_new_review := jsonb_build_object(
    'user_id', v_user_id::text,
    'drink', p_drink,
    'hygiene', p_hygiene,
    'atmosphere', p_atmosphere,
    'final', p_final,
    'created_at', now()
  );

  v_updated_reviews := v_reviews || jsonb_build_array(v_new_review);

  update public.stores
     set reviews = v_updated_reviews
   where id::text = p_store_id;

  return v_updated_reviews;
end;
$$;

revoke all on function public.submit_store_rating(text, numeric, numeric, numeric, numeric) from public;
grant execute on function public.submit_store_rating(text, numeric, numeric, numeric, numeric) to authenticated;
