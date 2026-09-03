-- Grant usage and execute on internal schema functions to authenticated role

grant usage on schema internal to authenticated;
grant execute on all functions in schema internal to authenticated;
