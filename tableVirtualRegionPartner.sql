SELECT 
    rp.display_name AS name,
    region.name AS region,
    rp.id AS partner_id,
    rp.administrative_dependency AS adm_dep,
    crl.season AS season,
    COALESCE(
        CASE 
            WHEN ru.login IS NULL OR ru.login = '' OR position('.' IN ru.login) = 0 OR position('@' IN ru.login) = 0 THEN '(no asignado)'
            ELSE CONCAT(
                substring(ru.login FROM 1 FOR position('.' IN ru.login) - 1), 
                ' ', 
                substring(ru.login FROM position('.' IN ru.login) + 1 FOR position('@' IN ru.login) - position('.' IN ru.login) - 1)
            )
        END,
        '(no asignado)'
    ) AS name_saler,
    MAX(CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM lead_cali_adoption_info lca
            LEFT JOIN product_template pt ON lca.cali_product_id = pt.id
            LEFT JOIN product_category pci ON pt.categ_id = pci.id
            WHERE crl.id = lca.lead_id 
                AND pt.id IS NOT NULL 
                AND pci.name IN (
                    SELECT pc.name 
                    FROM product_category pc
                    JOIN product_template pt ON pt.categ_id = pc.id
                    WHERE 1=1 
                    {% for filter in get_filters('category', remove_filter=True) %}
                        {% if filter.get('op') == 'IN' %}
                            AND pc.name IN ({{ "'" + "','".join(filter.get('val'))|replace("'", "''") + "'" }})
                        {% elif filter.get('op') == 'LIKE' %}
                            AND pc.name LIKE {{ "'" + filter.get('val')|replace("'", "''") + "'" }}
                        {% endif %}
                    {% endfor %}
                )
        ) THEN 1 ELSE 0 
    END) AS tiene_adoption,
    MAX(CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM lead_cali_adoption_info lca
            LEFT JOIN product_template pt ON lca.cali_product_id = pt.id
            LEFT JOIN product_category pci ON pt.categ_id = pci.id
            WHERE crl.id = lca.lead_id 
                AND pt.id IS NOT NULL 
                AND pci.name IN (
                    SELECT pc.name 
                    FROM product_category pc
                    JOIN product_template pt ON pt.categ_id = pc.id
                    WHERE 1=1 
                    {% for filter in get_filters('category', remove_filter=True) %}
                        {% if filter.get('op') == 'IN' %}
                            AND pc.name IN ({{ "'" + "','".join(filter.get('val'))|replace("'", "''") + "'" }})
                        {% elif filter.get('op') == 'LIKE' %}
                            AND pc.name LIKE {{ "'" + filter.get('val')|replace("'", "''") + "'" }}
                        {% endif %}
                    {% endfor %}
                )
        ) OR EXISTS (
            SELECT 1 
            FROM lead_competitor_adoption_info lcai
            WHERE crl.id = lcai.lead_id 
                AND lcai.lead_id IS NOT NULL
        ) THEN 1 ELSE 0 
    END) AS tiene_info
FROM 
    res_partner rp
JOIN 
    crm_lead crl ON rp.id = crl.partner_id
LEFT JOIN 
    res_country_state comuna ON rp.state_id = comuna.id
LEFT JOIN 
    res_country_state ciudad ON comuna.parent_id = ciudad.id
LEFT JOIN 
    res_country_state region ON ciudad.parent_id = region.id
RIGHT JOIN 
    res_users ru ON rp.user_id = ru.id
    
WHERE 
    crl.season = CAST((SELECT crm_user_authorized_season FROM res_company) AS INT)
    OR crl.season = CAST((SELECT crm_user_authorized_season - 1 FROM res_company) AS INT)
GROUP BY 
    rp.display_name, region.name, rp.id, crl.season, ru.login