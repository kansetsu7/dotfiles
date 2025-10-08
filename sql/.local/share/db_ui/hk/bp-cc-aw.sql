select bp.plan_no
from plan_items bp
join payment_infos pinfo on pinfo.basic_plan_id = bp.id
where bp.state not in ('pending', 'rejected', 'pre_submitted', 'submitted', 'expired', 'vested', 'underwriting', 'cancelled', 'confirmed', 'deleted')
and pinfo.pay_profile_code = 'CC-AW'
