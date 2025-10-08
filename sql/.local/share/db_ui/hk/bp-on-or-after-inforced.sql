select bp.plan_no
from plan_items bp
join plan_infos info on info.basic_plan_id = bp.id
where bp.state not in ('pending', 'rejected', 'pre_submitted', 'submitted', 'expired', 'vested', 'underwriting', 'cancelled', 'confirmed', 'deleted')
limit 1000
