PRINT '=========================================';
PRINT 'ЭТАП 1: ПОДГОТОВКА И ОБРАБОТКА ДАННЫХ';
PRINT '=========================================';
PRINT '';

-- ЭТАП 1: Подготовка данных
WITH BaseData AS (
    SELECT 
        o.order_id,
        o.warehouse_id,
        o.product_id,
        o.order_date,
        w.warehouse_name,
        w.region,
        p.product_name,
        CASE 
            WHEN p.product_name LIKE '%Ноутбук%' THEN 'Электроника'
            WHEN p.product_name LIKE '%Смартфон%' THEN 'Гаджеты'
            WHEN p.product_name LIKE '%Планшет%' THEN 'Портативные устройства'
            ELSE 'Прочее оборудование'
        END as product_category
    FROM Orders o
    JOIN Warehouses w ON o.warehouse_id = w.warehouse_id
    JOIN Products p ON o.product_id = p.product_id
    WHERE o.order_date >= DATEADD(MONTH, -12, GETDATE())
      AND o.order_date < GETDATE()
)

-- Вывод подготовленных данных
SELECT TOP 10
    'Пример обработанных данных' as info,
    region,
    warehouse_name,
    product_name,
    product_category,
    order_date
FROM BaseData
ORDER BY order_date DESC;
GO

PRINT '';
PRINT '=========================================';
PRINT 'ЭТАП 2: АНАЛИЗ РЕГИОНАЛЬНОЙ ЭФФЕКТИВНОСТИ';
PRINT '=========================================';
PRINT '';

-- ЭТАП 2: Региональный анализ
WITH RegionAnalysis AS (
    SELECT 
        w.region,
        COUNT(DISTINCT o.warehouse_id) as warehouse_count,
        COUNT(o.order_id) as total_orders,
        COUNT(DISTINCT o.product_id) as unique_products,
        CAST(COUNT(o.order_id) * 1.0 / NULLIF(COUNT(DISTINCT o.warehouse_id), 0) AS DECIMAL(10,2)) as orders_per_warehouse,
        RANK() OVER (ORDER BY COUNT(o.order_id) DESC) as rank_by_volume
    FROM Orders o
    JOIN Warehouses w ON o.warehouse_id = w.warehouse_id
    WHERE o.order_date >= DATEADD(MONTH, -12, GETDATE())
    GROUP BY w.region
)

SELECT 
    'Региональная эффективность' as analysis_type,
    region,
    warehouse_count,
    total_orders,
    unique_products,
    orders_per_warehouse,
    rank_by_volume,
    CASE 
        WHEN orders_per_warehouse > (SELECT AVG(orders_per_warehouse) FROM RegionAnalysis) * 1.3 
            THEN 'Высокая эффективность - рассмотреть расширение'
        WHEN orders_per_warehouse < (SELECT AVG(orders_per_warehouse) FROM RegionAnalysis) * 0.7 
            THEN 'Низкая эффективность - оптимизировать'
        ELSE 'Средняя эффективность'
    END as recommendation
FROM RegionAnalysis
ORDER BY orders_per_warehouse DESC;
GO

PRINT '';
PRINT '=========================================';
PRINT 'ЭТАП 3: АНАЛИЗ ТОВАРНОГО ПОРТФЕЛЯ';
PRINT '=========================================';
PRINT '';

-- ЭТАП 3: Товарный анализ
WITH ProductAnalysis AS (
    SELECT 
        p.product_id,
        p.product_name,
        CASE 
            WHEN p.product_name LIKE '%Ноутбук%' THEN 'Электроника'
            WHEN p.product_name LIKE '%Смартфон%' THEN 'Гаджеты'
            WHEN p.product_name LIKE '%Планшет%' THEN 'Портативные устройства'
            ELSE 'Прочее оборудование'
        END as product_category,
        COUNT(o.order_id) as total_orders,
        COUNT(DISTINCT w.region) as regions_covered,
        SUM(COUNT(o.order_id)) OVER (ORDER BY COUNT(o.order_id) DESC) as cumulative_orders,
        SUM(COUNT(o.order_id)) OVER () as grand_total_orders
    FROM Orders o
    JOIN Products p ON o.product_id = p.product_id
    JOIN Warehouses w ON o.warehouse_id = w.warehouse_id
    WHERE o.order_date >= DATEADD(MONTH, -12, GETDATE())
    GROUP BY p.product_id, p.product_name
)

SELECT TOP 15
    'ABC-анализ товаров' as analysis_type,
    product_name,
    product_category,
    total_orders,
    regions_covered,
    CASE 
        WHEN cumulative_orders <= grand_total_orders * 0.7 THEN 'A - Ключевые товары'
        WHEN cumulative_orders <= grand_total_orders * 0.9 THEN 'B - Стандартные товары'
        ELSE 'C - Нишевые товары'
    END as abc_category,
    RANK() OVER (ORDER BY total_orders DESC) as popularity_rank
FROM ProductAnalysis
ORDER BY total_orders DESC;
GO

PRINT '';
PRINT '=========================================';
PRINT 'ЭТАП 4: ВРЕМЕННОЙ АНАЛИЗ И СЕЗОННОСТЬ';
PRINT '=========================================';
PRINT '';

-- ЭТАП 4: Временной анализ
WITH TimeAnalysis AS (
    SELECT 
        w.region,
        YEAR(o.order_date) as order_year,
        MONTH(o.order_date) as order_month,
        DATENAME(MONTH, o.order_date) as month_name,
        COUNT(o.order_id) as monthly_orders,
        LAG(COUNT(o.order_id), 1) OVER (
            PARTITION BY w.region 
            ORDER BY YEAR(o.order_date), MONTH(o.order_date)
        ) as prev_month_orders
    FROM Orders o
    JOIN Warehouses w ON o.warehouse_id = w.warehouse_id
    WHERE o.order_date >= DATEADD(MONTH, -6, GETDATE())
    GROUP BY w.region, YEAR(o.order_date), MONTH(o.order_date), DATENAME(MONTH, o.order_date)
)

SELECT 
    'Динамика продаж по месяцам' as analysis_type,
    region,
    CONCAT(order_year, '-', RIGHT('0' + CAST(order_month AS VARCHAR(2)), 2)) as period,
    month_name,
    monthly_orders,
    prev_month_orders,
    monthly_orders - ISNULL(prev_month_orders, 0) as change,
    CASE 
        WHEN prev_month_orders > 0 
            THEN CAST((monthly_orders - prev_month_orders) * 100.0 / prev_month_orders AS DECIMAL(10,2))
        ELSE NULL
    END as change_percent,
    CASE 
        WHEN monthly_orders > ISNULL(prev_month_orders, 0) * 1.15 THEN 'Рост'
        WHEN monthly_orders < ISNULL(prev_month_orders, 0) * 0.85 THEN 'Спад'
        ELSE 'Стабильно'
    END as trend
FROM TimeAnalysis
WHERE order_year = YEAR(GETDATE()) OR (order_year = YEAR(GETDATE()) - 1 AND order_month >= MONTH(GETDATE()))
ORDER BY region, order_year DESC, order_month DESC;
GO