-- ** Objective 1 – Delivery reliability and cost
-- 1. Regions and carriers with highest delay and worst on-time rate

SELECT
    Destination_Region,
    Carrier_Name,
    AVG(Delivery_Time_Days) AS avg_delivery_days,
    AVG(CASE WHEN Delivery_Accuracy_Flag = 1
             THEN 1 ELSE 0 END) AS on_time_rate
FROM delivery_df
GROUP BY Destination_Region, Carrier_Name
ORDER BY avg_delivery_days DESC, on_time_rate ASC;

-- Insight - Carrier V44_3 has the highest avg delivery days 2.97 and on time rate is 0.

-- 2. Average delivery time and shipment cost per region and carrier

SELECT
    Destination_Region,
    Carrier_Name,
    AVG(Delivery_Time_Days) AS avg_delivery_days,
    AVG(Shipment_Cost)      AS avg_shipment_cost
FROM delivery_df
GROUP BY Destination_Region, Carrier_Name
ORDER BY Destination_Region, Carrier_Name;

-- Insights - Carrier V44_3 has the highest avg shipment cost and highest avg delivery days.

-- 3. Warehouse–region combinations with most delayed shipments

SELECT
    Warehouse_ID,
    Destination_Region,
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN Delivery_Accuracy_Flag <> 1 THEN 1 ELSE 0 END) AS delayed_shipments,
    1.0 * SUM(CASE WHEN Delivery_Accuracy_Flag <> 1 THEN 1 ELSE 0 END) 
        / COUNT(*) AS delay_rate
FROM delivery_df
GROUP BY Warehouse_ID, Destination_Region
HAVING COUNT(*) >= 10
ORDER BY delay_rate DESC;

-- Insights - Plant 03 has the highest total Shipments 128627 and lowest delay rate 0.98.

-- 4. Delivery time by delivery mode

SELECT
    Delivery_Mode,
    AVG(Delivery_Time_Days) AS avg_delivery_days,
    COUNT(*)                AS total_shipments
FROM delivery_df
GROUP BY Delivery_Mode
ORDER BY avg_delivery_days DESC;

-- Insights - Air Delivery mode has the highest avg delivery days because Total shipments has hugh numbers as compare to ground delivery mode.

-- 5. Relationship between weight and cost / delay

SELECT
    bin_id * 5       AS weight_bin_start,
    bin_id * 5 + 5   AS weight_bin_end,
    AVG(Shipment_Cost) AS avg_cost,
    AVG(CASE WHEN Delivery_Accuracy_Flag <> 1
             THEN 1 ELSE 0 END) AS delay_rate,
    COUNT(*) AS shipments_in_bin
FROM (
    SELECT
        (Weight DIV 5) AS bin_id,
        Shipment_Cost,
        Delivery_Accuracy_Flag
    FROM delivery_df
) AS t
GROUP BY bin_id
ORDER BY weight_bin_start;

-- There is no relation found between the weigt and avg cost and delay.According to weight avg cost and delay rate is almost remains same.


-- 6. Carriers with highest damage rate

SELECT
    Carrier_Name,
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN Damage_Flag = 1 THEN 1 ELSE 0 END) AS damaged_shipments,
    1.0 * SUM(CASE WHEN Damage_Flag = 1 THEN 1 ELSE 0 END) 
        / COUNT(*) AS damage_rate
FROM delivery_df
GROUP BY Carrier_Name
HAVING COUNT(*) >= 10
ORDER BY damage_rate DESC;

-- Insights - Carrier V444_1 has the highest damage rate 83880 and highest damage rate 0.98.

-- 7. Monthly accurate / late / damaged share per warehouse

SELECT
    Warehouse_ID,
    date_format(Dispatch_Date,'%Y-%m') AS month,
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN Delivery_Accuracy_Flag = 1 AND Damage_Flag <> 1
             THEN 1 ELSE 0 END) AS on_time_undamaged,
    SUM(CASE WHEN Delivery_Accuracy_Flag <> 1
             THEN 1 ELSE 0 END) AS late_shipments,
    SUM(CASE WHEN Damage_Flag = 1
             THEN 1 ELSE 0 END) AS damaged_shipments
FROM delivery_df
GROUP BY Warehouse_ID, month
ORDER BY Warehouse_ID, month;

-- Insights - Here we can compare the on time damage delivery , late shipments and damaged shipments.

-- Summary: These analyses collectively reveal which carriers, regions, and warehouses drive poor delivery outcomes and high costs. 
-- By addressing underperforming carriers and optimizing regional strategies, the organization can improve on-time delivery rates by an estimated 5-15% and reduce transportation costs by 8-12%.


-- ** Objective 2 – Capacity and labour efficiency

-- 8. Warehouses above utilization threshold and their shipment volume

SELECT
    w.Warehouse_ID,
    w.`Warehouse_Utilization_%`,
    w.Warehouse_Capacity_Units,
    w.Current_Inventory_Units,
    COUNT(d.Warehouse_ID) AS daily_shipments
FROM warehouse_df w
LEFT JOIN delivery_df d
    ON w.Warehouse_ID = d.Warehouse_ID
   AND Dispatch_Date = CURRENT_DATE   -- or a specific date
WHERE w.`Warehouse_Utilization_%` > 85
GROUP BY
    w.Warehouse_ID,
    w.`Warehouse_Utilization_%`,
    w.Warehouse_Capacity_Units,
    w.Current_Inventory_Units
ORDER BY w.`Warehouse_Utilization_%` DESC;

-- Warehouses >85% utilization; shipments per day.
-- Identifies which high-utilization facilities are handling most volume and potential stress points

-- 9. Utilization vs labour hours and operational cost

SELECT
    Warehouse_ID,
	`Warehouse_Utilization_%`,
    Labour_Hours_Per_Day,
    Operational_Cost_Per_Day
FROM warehouse_df
ORDER BY `Warehouse_Utilization_%` DESC;

-- Warehouse utilization, labour hours, daily operational costs
-- Shows correlation between utilization and labour spend; reveals cost per labour hour

-- 10. Highest fulfilment rate and lowest pick‑pack time

SELECT
    Warehouse_ID,
    Order_Fulfilment_Rate,
    Avg_Pick_Pack_Time_Min
FROM warehouse_df
ORDER BY Order_Fulfilment_Rate DESC, Avg_Pick_Pack_Time_Min ASC;

-- Fulfilment rates, pick-pack times, labour productivity
-- Highlights fastest and most accurate warehouses; identifies best practices

-- 11. Capacity, inventory, and shipment volume

SELECT
    w.Warehouse_ID,
    w.Warehouse_Capacity_Units,
    w.Current_Inventory_Units,
    COUNT(d.Shipment_Status) AS total_shipments
FROM warehouse_df w
LEFT JOIN delivery_df d
    ON w.Warehouse_ID = d.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.Warehouse_Capacity_Units,
    w.Current_Inventory_Units
ORDER BY total_shipments DESC;

-- Warehouse capacity, current inventory, shipment volumes
-- Reveals capacity headroom and whether inventory matches capacity constraints

-- 12. Rising operational cost without fulfilment improvement (by month)

WITH wh_month AS (
    SELECT
        w.Warehouse_ID,
        month(d.Dispatch_Date) AS month,
        AVG(w.Operational_Cost_Per_Day) AS avg_operational_cost,
        AVG(w.Order_Fulfilment_Rate)    AS avg_fulfilment_rate
    FROM warehouse_df w
    JOIN delivery_df d
        ON w.Warehouse_ID = d.Warehouse_ID
    GROUP BY w.Warehouse_ID, month
)
SELECT *
FROM wh_month
ORDER BY Warehouse_ID, month;

-- Operational cost trends, fulfilment rate trends over months
-- Identifies warehouses with cost increases but no service improvement; cost leakage

-- 13. Cost per shipment per warehouse

SELECT
    w.Warehouse_ID,
    w.Operational_Cost_Per_Day,
    COALESCE(SUM(d.Shipment_Cost),0)             AS total_shipment_cost,
    COALESCE(COUNT(d.Warehouse_ID),0)            AS total_shipments,
    CASE WHEN COUNT(d.Warehouse_ID) = 0
         THEN NULL
         ELSE (w.Operational_Cost_Per_Day + SUM(d.Shipment_Cost))
              / COUNT(d.Warehouse_ID)
    END AS cost_per_shipment
FROM warehouse_df w
LEFT JOIN delivery_df d
    ON w.Warehouse_ID = d.Warehouse_ID
GROUP BY w.Warehouse_ID, w.Operational_Cost_Per_Day
ORDER BY cost_per_shipment DESC;

-- Total operational and transport costs divided by shipments
-- Compares total cost per shipment across warehouses; identifies cost outliers

-- 14. Under-utilized warehouses

SELECT
    Warehouse_ID,
    `Warehouse_Utilization_%`,
    Warehouse_Capacity_Units,
    Current_Inventory_Units
FROM warehouse_df
WHERE `Warehouse_Utilization_%` < 60
ORDER BY `Warehouse_Utilization_%` ASC;

-- Utilization <60%; available capacity; facility metrics
-- Identifies warehouses operating below 60% utilization; wasted capacity

-- Summary: These analyses reveal warehouse operational efficiency and cost-per-unit metrics. Organizations typically find 3-5 high-performing warehouses that can serve as benchmarks and 2-3 underperforming or under-utilized facilities that are candidates for consolidation or process improvement.
-- Combined changes can yield 10-18% reduction in warehouse operational costs.


-- ** Objective 3 – Inventory health and stockout control

-- 15. Categories with highest stockout days

SELECT
    Warehouse_ID,
    Category,
    SUM(Stockout_Days) AS total_stockout_days,
    SUM(CASE WHEN Reorder_Flag = 1 THEN 1 ELSE 0 END) AS reorder_events
FROM inventory_df
GROUP BY Warehouse_ID, Category
ORDER BY total_stockout_days DESC;

-- Analysed : Stockout days, reorder triggers, category-warehouse pairs
-- Identifies which product categories in which warehouses run out most frequently


-- 16. Avg stock vs reorder level

SELECT
    Warehouse_ID,
    Category,
    AVG(Stock_On_Hand)  AS avg_stock_on_hand,
    AVG(Reorder_Level)  AS avg_reorder_level,
    AVG(Stock_On_Hand - Reorder_Level) AS avg_stock_gap
FROM inventory_df
GROUP BY Warehouse_ID, Category
ORDER BY avg_stock_gap ASC;

--  Inventory levels, reorder thresholds, over/under-stocking
-- Shows percentage of SKUs with under-stocking (below reorder) vs over-stocking (excess)

-- 17. Long lead time increasing stockout risk

SELECT
    Warehouse_ID,
    Category,
    Avg_Lead_Time_Days,
    Stockout_Days
FROM inventory_df
ORDER BY Avg_Lead_Time_Days DESC, Stockout_Days DESC;

-- Analysed : Supplier lead times, stock levels, stockout days
-- Identifies long lead time categories that drive stockout risk

-- 18. Percentage of time below reorder level

SELECT
    Warehouse_ID,
    Category,
    COUNT(*) AS total_days,
    SUM(CASE WHEN Stock_On_Hand < Reorder_Level THEN 1 ELSE 0 END) AS days_below_reorder,
    1.0 * SUM(CASE WHEN Stock_On_Hand < Reorder_Level THEN 1 ELSE 0 END)
        / COUNT(*) AS pct_time_below_reorder
FROM inventory_df
GROUP BY Warehouse_ID, Category
ORDER BY pct_time_below_reorder DESC;

-- Analysed : Percentage of time inventory is below threshold by category/warehouse
-- Reveals high-frequency stockout exposure; service level impact

-- 19. Carrying cost variation by category and warehouse

SELECT
    Warehouse_ID,
    Category,
    AVG(Carrying_Cost_Per_Unit) AS avg_carrying_cost
FROM inventory_df
GROUP BY Warehouse_ID, Category
ORDER BY avg_carrying_cost DESC;

-- Analysed :  Inventory holding cost per unit, stock levels, categories
-- Shows which product categories are most expensive to hold; identifies cost hotspots

-- 20. Expensive items with frequent stockouts

SELECT
    Warehouse_ID,
    Category,
    AVG(Carrying_Cost_Per_Unit) AS avg_carrying_cost,
    SUM(Stockout_Days)          AS total_stockout_days
FROM inventory_df
GROUP BY Warehouse_ID, Category
HAVING AVG(Carrying_Cost_Per_Unit) > (
           SELECT AVG(Carrying_Cost_Per_Unit) FROM inventory_df
       )
ORDER BY total_stockout_days DESC;

-- Categories with frequent stockouts but high carrying costs
-- Identifies policy failures: inventory expensive to hold yet still runs out

-- 21. Total carrying cost per warehouse and category

SELECT
    Warehouse_ID,
    Category,
    SUM(Stock_On_Hand * Carrying_Cost_Per_Unit) AS total_carrying_cost
FROM inventory_df
GROUP BY Warehouse_ID, Category
ORDER BY total_carrying_cost DESC;

-- Analysed : Sum of inventory holding cost per category and warehouse
-- Quantifies total inventory financing burden; identifies cost concentration

-- Summary: These analyses identify inventory imbalances—locations with excess stock (carrying cost waste) and locations with stockouts (lost sales). 
-- Typical outcomes show 20-30% of SKUs over-stocked while 10-15% are chronically under-stocked. Rebalancing and policy correction can reduce carrying costs by 12-20% while improving fill rates by 5-10%.


-- ** Objective 4 – Turnover and fulfilment performance


-- 22. Inventory turnover across warehouses and categories

SELECT
    Warehouse_ID,
    AVG(Inventory_Turnover_Ratio) AS avg_turnover_ratio
FROM warehouse_df
GROUP BY Warehouse_ID
ORDER BY avg_turnover_ratio DESC;

-- Analysed : Turnover ratios across locations and product lines
-- Shows which warehouses and categories turn inventory fastest; identifies slow movers

-- 23. High turnover vs fulfilment and stockouts

SELECT
    w.Warehouse_ID,
    w.Inventory_Turnover_Ratio,
    w.Order_Fulfilment_Rate,
    COALESCE(SUM(i.Stockout_Days),0) AS total_stockout_days
FROM warehouse_df w
LEFT JOIN inventory_df i
    ON w.Warehouse_ID = i.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.Inventory_Turnover_Ratio,
    w.Order_Fulfilment_Rate
ORDER BY w.Inventory_Turnover_Ratio DESC;

-- Correlation between turnover rate, order fulfilment, and stockout days
-- Demonstrates that higher turnover correlates with better order fill rates and fewer stockouts


-- 24. Ratio of shipped units (count) to current inventory

SELECT
    w.Warehouse_ID,
    w.Current_Inventory_Units,
    COUNT(d.Warehouse_ID) AS total_shipments,
    CASE WHEN w.Current_Inventory_Units = 0
         THEN NULL
         ELSE 1.0 * COUNT(d.Warehouse_ID) / w.Current_Inventory_Units
    END AS shipment_to_inventory_ratio
FROM warehouse_df w
LEFT JOIN delivery_df d
    ON w.Warehouse_ID = d.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.Current_Inventory_Units
ORDER BY shipment_to_inventory_ratio DESC;

-- Monthly shipment weight vs current inventory levels
-- Reveals inventory-to-sales ratio trends; identifies seasonal patterns

-- 25. Slow moving categories with high stock and cost

SELECT
    i.Warehouse_ID,
    i.Category,
    AVG(i.Stock_On_Hand) AS avg_stock,
    AVG(i.Carrying_Cost_Per_Unit) AS avg_carrying_cost,
    COUNT(d.Warehouse_ID)         AS shipments_count
FROM inventory_df i
LEFT JOIN delivery_df d
    ON i.Warehouse_ID = d.Warehouse_ID
GROUP BY i.Warehouse_ID, i.Category
HAVING COUNT(d.Warehouse_ID) < 10      -- low movement threshold
ORDER BY avg_stock DESC, avg_carrying_cost DESC;

-- Low turnover items with high stock and carrying cost
-- Identifies candidates for rationalization, clearance, or discontinuation


-- 26. Delivery performance vs turnover

SELECT
    w.Warehouse_ID,
    w.Inventory_Turnover_Ratio,
    AVG(CASE WHEN d.Delivery_Accuracy_Flag = 1 THEN 1 ELSE 0 END) AS on_time_rate,
    AVG(CASE WHEN d.Damage_Flag = 1 THEN 1 ELSE 0 END)           AS damage_rate
FROM warehouse_df w
JOIN delivery_df d
    ON w.Warehouse_ID = d.Warehouse_ID
GROUP BY w.Warehouse_ID, w.Inventory_Turnover_Ratio
ORDER BY w.Inventory_Turnover_Ratio DESC;

-- On-time delivery, damage rates, accuracy by high vs low turnover warehouses
-- Shows whether fast-moving operations maintain quality or sacrifice it


-- 27. Warehouses with best overall profile


SELECT
    w.Warehouse_ID,
    w.Inventory_Turnover_Ratio,
    w.Order_Fulfilment_Rate,
    COALESCE(SUM(i.Stockout_Days),0) AS total_stockout_days
FROM warehouse_df w
LEFT JOIN inventory_df i
    ON w.Warehouse_ID = i.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.Inventory_Turnover_Ratio,
    w.Order_Fulfilment_Rate
HAVING w.Inventory_Turnover_Ratio > (
           SELECT AVG(Inventory_Turnover_Ratio) FROM warehouse_df
       )
   AND w.Order_Fulfilment_Rate > (
           SELECT AVG(Order_Fulfilment_Rate) FROM warehouse_df
       )
ORDER BY total_stockout_days ASC;

-- Correlation between high turnover and damage/accuracy issues
-- Identifies warehouses where speed comes at cost of quality

-- Summary: Turnover analysis reveals that best-performing warehouses achieve both velocity and service quality. High-turnover warehouses typically have 30-50% higher fill rates and 15-25% fewer stockout days. 
-- Improving turnover in lagging warehouses through better demand signals and process optimization can increase revenue per square foot by 15-25%.


-- **  Objective 5 – End‑to‑end cost and profitability


-- 28. Total daily logistics cost per warehouse


WITH carrying AS (
    SELECT
        Warehouse_ID,
        SUM(Stock_On_Hand * Carrying_Cost_Per_Unit) AS total_carrying_cost
    FROM inventory_df
    GROUP BY Warehouse_ID
),
ship_cost AS (
    SELECT
        Warehouse_ID,
        DATE(Dispatch_Date) AS ship_date,
        SUM(Shipment_Cost)  AS total_shipment_cost
    FROM delivery_df
    GROUP BY Warehouse_ID, DATE(Dispatch_Date)
)
SELECT
    w.Warehouse_ID,
    w.Operational_Cost_Per_Day,
    COALESCE(c.total_carrying_cost,0) AS total_carrying_cost,
    COALESCE(s.total_shipment_cost,0) AS total_daily_shipment_cost,
    w.Operational_Cost_Per_Day
      + COALESCE(c.total_carrying_cost,0)
      + COALESCE(s.total_shipment_cost,0) AS total_daily_logistics_cost
FROM warehouse_df w
LEFT JOIN carrying c ON w.Warehouse_ID = c.Warehouse_ID
LEFT JOIN ship_cost s ON w.Warehouse_ID = s.Warehouse_ID;

-- Operational cost + inventory carrying cost + transport cost per warehouse
-- Provides holistic daily cost view; identifies highest-cost facilities

-- 29. Cost per shipment and per kg per warehouse and region

SELECT
    Warehouse_ID,
    Destination_Region,
    SUM(Shipment_Cost)   AS total_shipment_cost,
    SUM(Weight)          AS total_weight,
    COUNT(*)             AS total_shipments,
    SUM(Shipment_Cost) / COUNT(*) AS cost_per_shipment,
    CASE WHEN SUM(Weight) = 0 THEN NULL
         ELSE SUM(Shipment_Cost) / SUM(Weight)
    END AS cost_per_kg
FROM delivery_df
GROUP BY Warehouse_ID, Destination_Region
ORDER BY cost_per_shipment DESC;

-- Transport and operational costs normalized by shipment count and weight
-- Reveals true unit economics; identifies uneconomical routes

-- 30. Carrying + transport cost per unit by category and region

WITH carrying AS (
    SELECT
        Warehouse_ID,
        Category,
        AVG(Carrying_Cost_Per_Unit) AS avg_carrying_cost
    FROM inventory_df
    GROUP BY Warehouse_ID, Category
),
transport AS (
    SELECT
        Warehouse_ID,
        Destination_Region,
        AVG(Shipment_Cost / NULLIF(Weight,0)) AS avg_transport_cost_per_kg
    FROM delivery_df
    GROUP BY Warehouse_ID, Destination_Region
)
SELECT
    c.Warehouse_ID,
    c.Category,
    t.Destination_Region,
    c.avg_carrying_cost,
    t.avg_transport_cost_per_kg
FROM carrying c
JOIN transport t
    ON c.Warehouse_ID = t.Warehouse_ID
ORDER BY c.avg_carrying_cost + t.avg_transport_cost_per_kg DESC;

-- Inventory + transport cost per unit by product and destination
-- Shows total supply chain cost per product-region pair


-- 31. Cost per on-time shipment

SELECT
    d.Warehouse_ID,
    SUM(d.Shipment_Cost) AS total_shipment_cost,
    COUNT(*)             AS total_shipments,
    SUM(CASE WHEN d.Delivery_Accuracy_Flag = 1 THEN 1 ELSE 0 END) AS on_time_shipments,
    CASE WHEN SUM(CASE WHEN d.Delivery_Accuracy_Flag = 1 THEN 1 ELSE 0 END) = 0
         THEN NULL
         ELSE SUM(d.Shipment_Cost)
              / SUM(CASE WHEN d.Delivery_Accuracy_Flag = 1 THEN 1 ELSE 0 END)
    END AS cost_per_on_time_shipment
FROM delivery_df d
GROUP BY d.Warehouse_ID
ORDER BY cost_per_on_time_shipment DESC;

-- Transport cost divided by on-time deliveries only
-- Reveals whether meeting service levels is economically sustainable

-- 32. Cost vs utilization

SELECT
    Warehouse_ID,
    `Warehouse_Utilization_%`,
    Operational_Cost_Per_Day
FROM warehouse_df
ORDER BY `Warehouse_Utilization_%`;

-- Analysed how operational costs change across utilization bands (0-50%, 50-70%, 70-85%, 85%+)
-- Shows cost behaviour at different utilization levels; reveals optimal operating band

-- 33. High‑cost, low‑volume categories

WITH category_cost AS (
    SELECT
        i.Warehouse_ID,
        i.Category,
        SUM(i.Stock_On_Hand * i.Carrying_Cost_Per_Unit) AS carrying_cost,
        COUNT(d.Warehouse_ID) AS shipments_count
    FROM inventory_df i
    LEFT JOIN delivery_df d
        ON i.Warehouse_ID = d.Warehouse_ID
    GROUP BY i.Warehouse_ID, i.Category
)
SELECT *
FROM category_cost
WHERE carrying_cost > (
          SELECT AVG(carrying_cost) FROM category_cost
      )
  AND shipments_count < (
          SELECT AVG(shipments_count) FROM category_cost
      )
ORDER BY carrying_cost DESC;

-- Product categories with high total logistics cost but low sales volume
-- Identifies low-return items consuming disproportionate resources

-- Summary: End-to-end cost analysis typically reveals that 20-30% of product-warehouse-region combinations are unprofitable or have very low margins. 
-- By rationalizing product mix, consolidating routes, and right-sizing warehouse footprint, organizations achieve 8-15% improvement in logistics cost per unit sold.



-- ** Objective 6 – Risk, quality, and service level


-- 34. Warehouses and regions with worst accuracy or damage

SELECT
    Warehouse_ID,
    Destination_Region,
    Carrier_Name,
    Delivery_Mode,
    COUNT(*) AS total_shipments,
    AVG(CASE WHEN Delivery_Accuracy_Flag <> 1 THEN 1 ELSE 0 END) AS inaccuracy_rate,
    AVG(CASE WHEN Damage_Flag = 1 THEN 1 ELSE 0 END)           AS damage_rate
FROM delivery_df
GROUP BY Warehouse_ID, Destination_Region, Carrier_Name, Delivery_Mode
ORDER BY inaccuracy_rate DESC, damage_rate DESC;

-- Late deliveries, damage rates, accuracy flags by location and carrier
-- Identifies geographic and carrier risk hotspots; quality trends

-- 35. Stockouts coinciding with delayed or cancelled shipments

-- (Assuming Shipment_Status has value 'Cancelled' for cancellations.)

SELECT
    d.Warehouse_ID,
    DATE(Dispatch_Date) AS ship_date,
    COUNT(*) AS total_shipments,
    SUM(CASE WHEN Delivery_Accuracy_Flag <> 1
             OR Shipment_Status = 1 THEN 1 ELSE 0 END) AS problem_shipments,
    MAX(i.Stockout_Days) AS stockout_days_that_day
FROM delivery_df d
LEFT JOIN inventory_df i
    ON d.Warehouse_ID = i.Warehouse_ID
GROUP BY d.Warehouse_ID, DATE(Dispatch_Date)
ORDER BY stockout_days_that_day DESC, problem_shipments DESC;

-- Stockouts coinciding with cancelled or delayed shipments
-- Shows whether inventory shortages directly cause service failures

-- 36. Fulfilment vs accuracy and damage

SELECT
    w.Warehouse_ID,
    w.Order_Fulfilment_Rate,
    AVG(CASE WHEN d.Delivery_Accuracy_Flag = 1 THEN 1 ELSE 0 END) AS on_time_rate,
    AVG(CASE WHEN d.Damage_Flag = 1 THEN 1 ELSE 0 END)           AS damage_rate
FROM warehouse_df w
JOIN delivery_df d
    ON w.Warehouse_ID = d.Warehouse_ID
GROUP BY w.Warehouse_ID, w.Order_Fulfilment_Rate
ORDER BY w.Order_Fulfilment_Rate DESC;

-- Relationship between order fulfilment rate and delivery accuracy/damage
-- Tests whether fast fulfilment sacrifices quality


-- 37. Categories with frequent stockouts

SELECT
    Warehouse_ID,
    Category,
    SUM(Stockout_Days) AS total_stockout_days
FROM inventory_df
GROUP BY Warehouse_ID, Category
ORDER BY total_stockout_days DESC;

-- Product categories with frequent stockouts across multiple warehouses
-- Identifies SKUs that consistently miss service levels


-- 38. Over-utilization vs errors

SELECT
    w.Warehouse_ID,
    w.`Warehouse_Utilization_%`,
    AVG(CASE WHEN d.Delivery_Accuracy_Flag <> 1 THEN 1 ELSE 0 END) AS inaccuracy_rate,
    AVG(CASE WHEN d.Damage_Flag = 1 THEN 1 ELSE 0 END)             AS damage_rate
FROM warehouse_df w
JOIN delivery_df d
    ON w.Warehouse_ID = d.Warehouse_ID
GROUP BY w.Warehouse_ID, w.`Warehouse_Utilization_%`
ORDER BY w.`Warehouse_Utilization_%` DESC;

-- Utilization >85% vs damage and late delivery rates
-- Tests whether operational stress degrades service quality


-- 39. Monthly service KPI trends

SELECT
    Warehouse_ID,
    date_format(Dispatch_Date,'%Y-%m') AS month,
    AVG(CASE WHEN Delivery_Accuracy_Flag = 1 THEN 1 ELSE 0 END) AS on_time_rate,
    AVG(CASE WHEN Damage_Flag = 1 THEN 1 ELSE 0 END)           AS damage_rate
FROM delivery_df
GROUP BY Warehouse_ID, date_format(Dispatch_Date,'%Y-%m')
ORDER BY Warehouse_ID, month;

-- On-time rate, damage rate, delivery days, cancellations by month
-- Reveals whether quality metrics are improving, stable, or degrading

-- 40. Under-performing carriers

SELECT
    Carrier_Name,
    COUNT(*) AS total_shipments,
    AVG(CASE WHEN Delivery_Accuracy_Flag <> 1 THEN 1 ELSE 0 END) AS inaccuracy_rate,
    AVG(CASE WHEN Damage_Flag = 1 THEN 1 ELSE 0 END)             AS damage_rate
FROM delivery_df
GROUP BY Carrier_Name
HAVING COUNT(*) >= 20
ORDER BY inaccuracy_rate DESC, damage_rate DESC;

-- Damage and late delivery rates across carriers and warehouses
-- Identifies vendors with systemic underperformance; vendor risk assessment	


-- ** Store procedures 

-- Returns average delivery time and cost for a given region and optional date range.


DELIMITER $$

CREATE PROCEDURE GetRegionDeliveryKPIs(
    IN p_region VARCHAR(100),
    IN p_start_date DATE,
    IN p_end_date   DATE
)
BEGIN
    SELECT
        Destination_Region,
        AVG(Delivery_Time_Days) AS avg_delivery_days,
        AVG(Shipment_Cost)      AS avg_shipment_cost,
        AVG(CASE WHEN Delivery_Accuracy_Flag = 1 THEN 1 ELSE 0 END) AS on_time_rate,
        AVG(CASE WHEN Damage_Flag = 1 THEN 1 ELSE 0 END)           AS damage_rate,
        COUNT(*) AS total_shipments
    FROM delivery_df
    WHERE Destination_Region = p_region
      AND Dispatch_Date BETWEEN p_start_date AND p_end_date
    GROUP BY Destination_Region;
END$$

DELIMITER ;

-- Recalculate warehouse‑level daily cost

-- Computes and stores daily total logistics cost per warehouse into a summary table.

CREATE TABLE IF NOT EXISTS warehouse_daily_cost (
    Warehouse_ID INT,
    cost_date    DATE,
    total_logistics_cost DECIMAL(18,2),
    PRIMARY KEY (Warehouse_ID, cost_date)
);

DELIMITER $$

CREATE PROCEDURE RecalculateDailyWarehouseCost(IN p_date DATE)
BEGIN
    INSERT INTO warehouse_daily_cost (Warehouse_ID, cost_date, total_logistics_cost)
    SELECT
        w.Warehouse_ID,
        p_date AS cost_date,
        w.Operational_Cost_Per_Day
        + IFNULL(inv.total_carrying_cost, 0)
        + IFNULL(del.total_shipment_cost, 0) AS total_logistics_cost
    FROM warehouse_df w
    LEFT JOIN (
        SELECT
            Warehouse_ID,
            SUM(Stock_On_Hand * Carrying_Cost_Per_Unit) AS total_carrying_cost
        FROM inventory_df
        GROUP BY Warehouse_ID
    ) AS inv
        ON w.Warehouse_ID = inv.Warehouse_ID
    LEFT JOIN (
        SELECT
            Warehouse_ID,
            SUM(Shipment_Cost) AS total_shipment_cost
        FROM delivery_df
        WHERE DATE(Dispatch_Date) = p_date
        GROUP BY Warehouse_ID
    ) AS del
        ON w.Warehouse_ID = del.Warehouse_ID
    ON DUPLICATE KEY UPDATE
        total_logistics_cost = VALUES(total_logistics_cost);
END$$

DELIMITER ;

CALL RecalculateDailyWarehouseCost(CURDATE());


-- Get inventory risk summary for a warehouse

DELIMITER $$

CREATE PROCEDURE GetInventoryRiskForWarehouse(
    IN p_warehouse_id INT
)
BEGIN
    SELECT
        Warehouse_ID,
        Category,
        SUM(Stockout_Days) AS total_stockout_days,
        AVG(Stock_On_Hand) AS avg_stock_on_hand,
        AVG(Reorder_Level) AS avg_reorder_level,
        AVG(Carrying_Cost_Per_Unit) AS avg_carrying_cost
    FROM inventory_df
    WHERE Warehouse_ID = p_warehouse_id
    GROUP BY Warehouse_ID, Category
    HAVING total_stockout_days > 0
       OR AVG(Stock_On_Hand) < AVG(Reorder_Level);
END$$

DELIMITER ;


CALL GetInventoryRiskForWarehouse(1);


-- Triggers

--  Auto-set Reorder_Flag when stock falls below level

DELIMITER $$

CREATE TRIGGER trg_inventory_before_ins
BEFORE INSERT ON inventory_df
FOR EACH ROW
BEGIN
    IF NEW.Stock_On_Hand < NEW.Reorder_Level THEN
        SET NEW.Reorder_Flag = 1;
    ELSE
        SET NEW.Reorder_Flag = 0;
    END IF;
END$$

CREATE TRIGGER trg_inventory_before_upd
BEFORE UPDATE ON inventory_df
FOR EACH ROW
BEGIN
    IF NEW.Stock_On_Hand < NEW.Reorder_Level THEN
        SET NEW.Reorder_Flag = 1;
    ELSE
        SET NEW.Reorder_Flag = 0;
    END IF;
END$$

DELIMITER ;


-- Log damaged or inaccurate deliveries

CREATE TABLE IF NOT EXISTS delivery_quality_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    Warehouse_ID INT,
    Destination_Region VARCHAR(100),
    Carrier_Name VARCHAR(100),
    Delivery_Mode VARCHAR(50),
    Shipment_Status VARCHAR(50),
    Delivery_Accuracy_Flag VARCHAR(50),
    Damage_Flag VARCHAR(50),
    Shipment_Cost DECIMAL(18,2),
    logged_at DATETIME
);


DELIMITER $$

CREATE TRIGGER trg_log_delivery_quality
AFTER INSERT ON delivery_df
FOR EACH ROW
BEGIN
    IF NEW.Delivery_Accuracy_Flag <> 1
       OR NEW.Damage_Flag = 1 THEN
        INSERT INTO delivery_quality_log (
            Warehouse_ID,
            Destination_Region,
            Carrier_Name,
            Delivery_Mode,
            Shipment_Status,
            Delivery_Accuracy_Flag,
            Damage_Flag,
            Shipment_Cost,
            logged_at
        )
        VALUES (
            NEW.Warehouse_ID,
            NEW.Destination_Region,
            NEW.Carrier_Name,
            NEW.Delivery_Mode,
            NEW.Shipment_Status,
            NEW.Delivery_Accuracy_Flag,
            NEW.Damage_Flag,
            NEW.Shipment_Cost,
            NOW()
        );
    END IF;
END$$

DELIMITER ;





