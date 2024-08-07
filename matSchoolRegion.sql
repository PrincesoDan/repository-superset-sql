SELECT 
    'Matrículas' as "Tipo",  -- Campo dummy para agrupación de matrículas
    rcs.name AS "región",
    SUM(CASE WHEN ccs.id = 4 THEN syi.number_of_students ELSE NULL END) AS "en propuesta_mat",
    SUM(CASE WHEN ccs.id = 5 THEN syi.number_of_students ELSE NULL END) AS "en negociacion_mat",
    SUM(CASE WHEN ccs.id = 3 THEN syi.number_of_students ELSE NULL END) AS "en calificación_mat",
    SUM(CASE WHEN ccs.id = 15 THEN syi.number_of_students ELSE NULL END) AS "sin informacion_mat",
    SUM(CASE WHEN ccs.id IN (4, 5, 3, 15) THEN syi.number_of_students ELSE NULL END) AS "total_mat"

FROM 
    school_year_info_report syi
JOIN 
    crm_lead crl 
ON 
    syi.partner_id = crl.partner_id
JOIN 
    crm_case_stage ccs 
ON 
    crl.stage_id = ccs.id
JOIN 
    res_country_state rcs 
ON 
    syi.region = rcs.id
WHERE 
    crl.season = CAST((SELECT crm_user_authorized_season FROM res_company) AS INT)
GROUP BY 
    rcs.name
    
UNION ALL

SELECT 
'Colegios' as "Tipo",
 rcs.name AS "región",
COUNT(DISTINCT CASE WHEN ccs.id = 4 THEN crl.partner_id ELSE NULL END) AS "en propuesta",
COUNT(DISTINCT CASE WHEN ccs.id = 5 THEN crl.partner_id ELSE NULL END) AS "en negociacion",
COUNT(DISTINCT CASE WHEN ccs.id = 3 THEN crl.partner_id ELSE NULL END) AS "en calificación",
COUNT(DISTINCT CASE WHEN ccs.id = 15 THEN crl.partner_id ELSE NULL END) AS "sin informacion",
COUNT(DISTINCT CASE WHEN ccs.id IN (4, 5, 3, 15) THEN crl.partner_id ELSE NULL END) AS "total_unique_partners"
    
FROM 
    school_year_info_report syi
JOIN 
    crm_lead crl 
ON 
    syi.partner_id = crl.partner_id
JOIN 
    crm_case_stage ccs 
ON 
    crl.stage_id = ccs.id
JOIN 
    res_country_state rcs 
ON 
    syi.region = rcs.id
WHERE 
    crl.season = CAST((SELECT crm_user_authorized_season FROM res_company) AS INT)
GROUP BY 
    rcs.name
