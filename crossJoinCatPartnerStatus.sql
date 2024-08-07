WITH dr AS (
  SELECT 
    rp.display_name AS name,
    region.name AS region,
    pc.name AS category,
    rp.id AS partner_id,
    crl.season AS season,
    MAX(CASE 
        WHEN EXISTS (
            SELECT 1 FROM lead_cali_adoption_info lca
            LEFT JOIN product_template pt ON lca.cali_product_id = pt.id
            LEFT JOIN product_category pci ON pt.categ_id = pci.id
            WHERE crl.id = lca.lead_id AND pt.id IS NOT NULL AND pc.name = pci.name
        ) THEN 1 ELSE 0 
    END) AS tiene_adoption,
    MAX(CASE 
        WHEN EXISTS (
            SELECT 1 FROM lead_cali_adoption_info lca
            LEFT JOIN product_template pt ON lca.cali_product_id = pt.id
            LEFT JOIN product_category pci ON pt.categ_id = pci.id
            WHERE crl.id = lca.lead_id AND pt.id IS NOT NULL AND pc.name = pci.name
        ) OR EXISTS (
            SELECT 1 FROM lead_competitor_adoption_info lcai
            WHERE crl.id = lcai.lead_id AND lcai.lead_id IS NOT NULL
        ) THEN 1 ELSE 0 
    END) AS tiene_info
  FROM 
    res_partner rp
  JOIN 
    crm_lead crl ON rp.id = crl.partner_id
  CROSS JOIN 
    (SELECT pc.name AS name

FROM product_template pt 
JOIN product_category pc ON pt.categ_id = pc.id
JOIN lead_cali_adoption_info lca ON lca.cali_product_id = pt.id
JOIN crm_lead crl ON crl.id = lca.lead_id
WHERE crl.season = CAST((SELECT crm_user_authorized_season FROM res_company) AS INT)
AND 1=1
        {% for filter in get_filters('category', remove_filter=True) %}
            {% if filter.get('op') == 'IN' %}
                AND pc.name IN ({{ "'" + "','".join(filter.get('val'))|replace("'", "''") + "'" }})
            {% elif filter.get('op') == 'LIKE' %}
                AND pc.name LIKE {{ "'" + filter.get('val')|replace("'", "''") + "'" }}
            {% endif %}
        {% endfor %}
GROUP BY pc.name) AS pc 
  LEFT JOIN 
    res_country_state comuna ON rp.state_id = comuna.id
  LEFT JOIN 
    res_country_state ciudad ON comuna.parent_id = ciudad.id
  LEFT JOIN 
    res_country_state region ON ciudad.parent_id = region.id
  
  WHERE crl.season = CAST((SELECT crm_user_authorized_season FROM res_company) AS INT)
      OR crl.season = CAST((SELECT crm_user_authorized_season -1 FROM res_company) AS INT)
  GROUP BY 
    rp.display_name, region.name, pc.name, rp.id, crl.season
)


--CONSULTA principal




SELECT 
  hii.name AS name,
  hii.region AS region,
  hii.category AS category,
  hii.partner_id AS partner_id,
  hii.status_adoption_current AS status_current,
  hii.status_adoption_prev AS status_prev,
  CASE
    --casos nulls
    WHEN hii.status_adoption_prev IS NULL AND hii.status_adoption_current = 1 THEN 'De no adoptado a adoptado'
    WHEN hii.status_adoption_prev IS NULL AND hii.status_adoption_current = 2 THEN 'Se mantiene no adoptado'
    WHEN hii.status_adoption_prev IS NULL AND hii.status_adoption_current = 3 THEN 'Se mantiene sin info'
    WHEN hii.status_adoption_prev = 1 AND hii.status_adoption_current IS NULL THEN 'De adoptado a sin info'
    WHEN hii.status_adoption_prev = 2 AND hii.status_adoption_current IS NULL THEN 'De no adoptado a sin info'
    WHEN hii.status_adoption_prev = 3 AND hii.status_adoption_current IS NULL THEN 'Se mantiene sin info'
    WHEN hii.status_adoption_prev IS NULL AND hii.status_adoption_current IS NULL THEN 'Se mantiene sin info y NULL'
    
    --comparación de estados
    WHEN hii.status_adoption_prev = 1 AND hii.status_adoption_current = 1 THEN 'Se mantiene adoptado'
    WHEN hii.status_adoption_prev = 1 AND hii.status_adoption_current = 2 THEN 'De adoptado a no adoptado'
    WHEN hii.status_adoption_prev = 1 AND hii.status_adoption_current = 3 THEN 'De adoptado a sin info'
    WHEN hii.status_adoption_prev = 2 AND hii.status_adoption_current = 1 THEN 'De no adoptado a adoptado'
    WHEN hii.status_adoption_prev = 2 AND hii.status_adoption_current = 2 THEN 'Se mantiene no adoptado'
    WHEN hii.status_adoption_prev = 2 AND hii.status_adoption_current = 3 THEN 'De no adoptado a sin info'
    WHEN hii.status_adoption_prev = 3 AND hii.status_adoption_current = 2 THEN 'De sin info a con info'
    WHEN hii.status_adoption_prev = 3 AND hii.status_adoption_current = 3 THEN 'Se mantiene sin info'
    WHEN hii.status_adoption_prev = 3 AND hii.status_adoption_current = 1 THEN 'De no adoptado a adoptado'
    ELSE 'Otros casos'
  END AS status_change
FROM (
      SELECT
         current.name,
         current.region,
         current.category,
         current.partner_id,
    current.status_adoption AS status_adoption_current,
    prev.status_adoption AS status_adoption_prev
  FROM
    (
      SELECT
        dr.name AS name,
        dr.region AS region,
        dr.category AS category,
        dr.partner_id AS partner_id,
        CASE
            WHEN tiene_info > 0 AND tiene_adoption > 0 THEN 1
            WHEN tiene_info > 0 AND tiene_adoption = 0 THEN 2
            ELSE 3
        END AS status_adoption
      FROM 
        dr
      WHERE dr.season = CAST((SELECT crm_user_authorized_season FROM res_company) AS INT)
        
    ) AS current
  FULL OUTER JOIN
    (SELECT
        dr.name AS name,
        dr.region AS region,
        dr.category AS category,
        dr.partner_id AS partner_id,
        CASE
            WHEN tiene_info > 0 AND tiene_adoption > 0 THEN 1
            WHEN tiene_info > 0 AND tiene_adoption = 0 THEN 2
            ELSE 3
        END AS status_adoption
      FROM 
        dr
      WHERE dr.season = CAST((SELECT crm_user_authorized_season -1 FROM res_company) AS INT)
      ) AS prev
    ON current.partner_id = prev.partner_id AND current.category = prev.category
) AS hii
--WHERE hii.name = 'COLEGIO CALBUCO'
ORDER BY hii.name, hii.category;