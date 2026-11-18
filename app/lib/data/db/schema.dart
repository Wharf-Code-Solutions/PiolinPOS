/// Esquema SQLite de PiolinPOS (versión 1).
///
/// Convenciones: ids UUID v7 (TEXT), dinero en centavos (INTEGER), cantidades en
/// milésimas (*_milli), porcentajes en puntos base (*_bp, 1000 = 10 %), fechas ISO-8601
/// UTC (TEXT) y `business_date` 'YYYY-MM-DD' local. Borrado lógico con `active`/`deleted_at`.
///
/// Para cambiar el esquema: subir [schemaVersion] y agregar la migración en
/// [migrations] (nunca editar sentencias de una versión ya publicada).
const schemaVersion = 1;

const schemaV1 = <String>[
  '''
  CREATE TABLE settings (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )''',
  '''
  CREATE TABLE categories (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    icon        TEXT NOT NULL DEFAULT 'caja',
    kind        TEXT NOT NULL DEFAULT 'menu' CHECK (kind IN ('menu','inventario')),
    sort_order  INTEGER NOT NULL DEFAULT 0,
    active      INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
  )''',
  '''
  CREATE TABLE suppliers (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    phone       TEXT,
    notes       TEXT,
    active      INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
  )''',
  '''
  CREATE TABLE inventory_items (
    id                    TEXT PRIMARY KEY,
    name                  TEXT NOT NULL,
    category_id           TEXT NOT NULL REFERENCES categories(id),
    unit                  TEXT NOT NULL CHECK (unit IN ('PZA','KG','L')),
    barcode               TEXT,
    tolerance_bp          INTEGER NOT NULL DEFAULT 0,
    min_stock_milli       INTEGER NOT NULL DEFAULT 0,
    current_stock_milli   INTEGER NOT NULL DEFAULT 0,
    last_unit_cost_cents  INTEGER,
    default_supplier_id   TEXT REFERENCES suppliers(id),
    location              TEXT NOT NULL DEFAULT '',
    active                INTEGER NOT NULL DEFAULT 1,
    created_at            TEXT NOT NULL,
    updated_at            TEXT NOT NULL
  )''',
  '''
  CREATE TABLE products (
    id                 TEXT PRIMARY KEY,
    category_id        TEXT NOT NULL REFERENCES categories(id),
    name               TEXT NOT NULL,
    description        TEXT NOT NULL DEFAULT '',
    price_cents        INTEGER NOT NULL CHECK (price_cents >= 0),
    barcode            TEXT,
    icon               TEXT NOT NULL DEFAULT 'taco',
    note_placeholder   TEXT NOT NULL DEFAULT 'Nota',
    favorite           INTEGER NOT NULL DEFAULT 0,
    available          INTEGER NOT NULL DEFAULT 1,
    active             INTEGER NOT NULL DEFAULT 1,
    inventory_item_id  TEXT REFERENCES inventory_items(id),
    consume_qty_milli  INTEGER NOT NULL DEFAULT 1000,
    sort_order         INTEGER NOT NULL DEFAULT 0,
    created_at         TEXT NOT NULL,
    updated_at         TEXT NOT NULL
  )''',
  '''
  CREATE TABLE product_price_history (
    id               TEXT PRIMARY KEY,
    product_id       TEXT NOT NULL REFERENCES products(id),
    old_price_cents  INTEGER NOT NULL,
    new_price_cents  INTEGER NOT NULL,
    changed_at       TEXT NOT NULL
  )''',
  '''
  CREATE TABLE modifier_groups (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    min_select  INTEGER NOT NULL DEFAULT 0,
    max_select  INTEGER NOT NULL DEFAULT 1,
    active      INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL,
    CHECK (max_select >= min_select)
  )''',
  '''
  CREATE TABLE modifiers (
    id                 TEXT PRIMARY KEY,
    group_id           TEXT NOT NULL REFERENCES modifier_groups(id),
    name               TEXT NOT NULL,
    price_delta_cents  INTEGER NOT NULL DEFAULT 0,
    is_default         INTEGER NOT NULL DEFAULT 0,
    sort_order         INTEGER NOT NULL DEFAULT 0,
    active             INTEGER NOT NULL DEFAULT 1,
    created_at         TEXT NOT NULL,
    updated_at         TEXT NOT NULL
  )''',
  '''
  CREATE TABLE product_modifier_groups (
    product_id  TEXT NOT NULL REFERENCES products(id),
    group_id    TEXT NOT NULL REFERENCES modifier_groups(id),
    sort_order  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (product_id, group_id)
  )''',
  '''
  CREATE TABLE promotions (
    id                  TEXT PRIMARY KEY,
    name                TEXT NOT NULL,
    type                TEXT NOT NULL CHECK (type IN ('PERCENT_OFF','FIXED_PRICE_BUNDLE','BUY_X_GET_Y')),
    percent_bp          INTEGER,
    bundle_price_cents  INTEGER,
    buy_qty             INTEGER,
    free_qty            INTEGER,
    starts_on           TEXT,
    ends_on             TEXT,
    weekdays_mask       INTEGER NOT NULL DEFAULT 127,
    start_time          TEXT,
    end_time            TEXT,
    active              INTEGER NOT NULL DEFAULT 1,
    created_at          TEXT NOT NULL,
    updated_at          TEXT NOT NULL
  )''',
  '''
  CREATE TABLE promotion_products (
    promotion_id  TEXT NOT NULL REFERENCES promotions(id),
    product_id    TEXT NOT NULL REFERENCES products(id),
    required_qty  INTEGER NOT NULL DEFAULT 1 CHECK (required_qty > 0),
    PRIMARY KEY (promotion_id, product_id)
  )''',
  '''
  CREATE TABLE shifts (
    id                   TEXT PRIMARY KEY,
    business_date        TEXT NOT NULL,
    status               TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','CLOSED')),
    opening_cash_cents   INTEGER NOT NULL DEFAULT 0,
    expected_cash_cents  INTEGER,
    counted_cash_cents   INTEGER,
    difference_cents     INTEGER,
    notes                TEXT,
    opened_at            TEXT NOT NULL,
    closed_at            TEXT
  )''',
  "CREATE UNIQUE INDEX ux_shifts_open ON shifts(status) WHERE status = 'OPEN'",
  '''
  CREATE TABLE cash_movements (
    id            TEXT PRIMARY KEY,
    shift_id      TEXT NOT NULL REFERENCES shifts(id),
    type          TEXT NOT NULL CHECK (type IN ('IN','OUT')),
    amount_cents  INTEGER NOT NULL CHECK (amount_cents > 0),
    reason        TEXT NOT NULL,
    created_at    TEXT NOT NULL
  )''',
  '''
  CREATE TABLE orders (
    id                    TEXT PRIMARY KEY,
    shift_id              TEXT NOT NULL REFERENCES shifts(id),
    business_date         TEXT NOT NULL,
    folio                 INTEGER NOT NULL,
    customer_name         TEXT NOT NULL DEFAULT 'Mostrador',
    channel               TEXT NOT NULL DEFAULT 'LOCAL'   CHECK (channel IN ('LOCAL','WHATSAPP')),
    dining_option         TEXT NOT NULL DEFAULT 'DINE_IN' CHECK (dining_option IN ('DINE_IN','TAKEOUT')),
    status                TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','PAID','CANCELLED','MERGED')),
    merged_into_order_id  TEXT REFERENCES orders(id),
    subtotal_cents        INTEGER NOT NULL DEFAULT 0,
    promo_discount_cents  INTEGER NOT NULL DEFAULT 0,
    discount_bp           INTEGER NOT NULL DEFAULT 0 CHECK (discount_bp BETWEEN 0 AND 10000),
    discount_cents        INTEGER NOT NULL DEFAULT 0,
    discount_reason       TEXT,
    total_cents           INTEGER NOT NULL DEFAULT 0,
    cancel_reason         TEXT,
    opened_at             TEXT NOT NULL,
    paid_at               TEXT,
    cancelled_at          TEXT,
    updated_at            TEXT NOT NULL,
    UNIQUE (business_date, folio),
    CHECK (status <> 'MERGED'    OR merged_into_order_id IS NOT NULL),
    CHECK (status <> 'CANCELLED' OR cancel_reason IS NOT NULL),
    CHECK (discount_bp = 0       OR discount_reason IS NOT NULL)
  )''',
  '''
  CREATE TABLE order_rounds (
    id              TEXT PRIMARY KEY,
    order_id        TEXT NOT NULL REFERENCES orders(id),
    round_no        INTEGER NOT NULL,
    print_status    TEXT NOT NULL DEFAULT 'PENDING' CHECK (print_status IN ('PENDING','PRINTED','FAILED')),
    print_attempts  INTEGER NOT NULL DEFAULT 0,
    printed_at      TEXT,
    created_at      TEXT NOT NULL,
    UNIQUE (order_id, round_no)
  )''',
  '''
  CREATE TABLE order_items (
    id                TEXT PRIMARY KEY,
    order_id          TEXT NOT NULL REFERENCES orders(id),
    round_id          TEXT NOT NULL REFERENCES order_rounds(id),
    product_id        TEXT NOT NULL REFERENCES products(id),
    product_name      TEXT NOT NULL,
    unit_price_cents  INTEGER NOT NULL,
    modifiers_cents   INTEGER NOT NULL DEFAULT 0,
    qty               INTEGER NOT NULL CHECK (qty > 0),
    notes             TEXT NOT NULL DEFAULT '',
    status            TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','VOIDED')),
    void_reason       TEXT,
    created_at        TEXT NOT NULL
  )''',
  '''
  CREATE TABLE order_item_modifiers (
    order_item_id      TEXT NOT NULL REFERENCES order_items(id),
    modifier_id        TEXT NOT NULL,
    modifier_name      TEXT NOT NULL,
    price_delta_cents  INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (order_item_id, modifier_id)
  )''',
  '''
  CREATE TABLE order_promotions (
    id              TEXT PRIMARY KEY,
    order_id        TEXT NOT NULL REFERENCES orders(id),
    promotion_id    TEXT NOT NULL,
    promotion_name  TEXT NOT NULL,
    times_applied   INTEGER NOT NULL DEFAULT 1,
    discount_cents  INTEGER NOT NULL CHECK (discount_cents >= 0)
  )''',
  '''
  CREATE TABLE payments (
    id              TEXT PRIMARY KEY,
    order_id        TEXT NOT NULL REFERENCES orders(id),
    shift_id        TEXT NOT NULL REFERENCES shifts(id),
    method          TEXT NOT NULL CHECK (method IN ('CASH','TRANSFER')),
    amount_cents    INTEGER NOT NULL CHECK (amount_cents > 0),
    received_cents  INTEGER,
    change_cents    INTEGER,
    reference       TEXT,
    created_at      TEXT NOT NULL
  )''',
  '''
  CREATE TABLE expense_categories (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    kind        TEXT NOT NULL CHECK (kind IN ('SUPPLIES','OPERATING','UNFORESEEN')),
    waste_bp    INTEGER NOT NULL DEFAULT 0,
    active      INTEGER NOT NULL DEFAULT 1,
    created_at  TEXT NOT NULL,
    updated_at  TEXT NOT NULL
  )''',
  '''
  CREATE TABLE expenses (
    id                  TEXT PRIMARY KEY,
    business_date       TEXT NOT NULL,
    shift_id            TEXT REFERENCES shifts(id),
    category_id         TEXT NOT NULL REFERENCES expense_categories(id),
    supplier_id         TEXT REFERENCES suppliers(id),
    amount_cents        INTEGER NOT NULL CHECK (amount_cents > 0),
    payment_method      TEXT NOT NULL CHECK (payment_method IN ('CASH','TRANSFER')),
    paid_from_register  INTEGER NOT NULL DEFAULT 0,
    description         TEXT NOT NULL DEFAULT '',
    created_at          TEXT NOT NULL,
    deleted_at          TEXT,
    CHECK (paid_from_register = 0 OR shift_id IS NOT NULL)
  )''',
  '''
  CREATE TABLE purchase_items (
    id                 TEXT PRIMARY KEY,
    expense_id         TEXT NOT NULL REFERENCES expenses(id),
    inventory_item_id  TEXT REFERENCES inventory_items(id),
    description        TEXT NOT NULL,
    qty_milli          INTEGER NOT NULL CHECK (qty_milli > 0),
    total_cents        INTEGER NOT NULL CHECK (total_cents >= 0),
    created_at         TEXT NOT NULL
  )''',
  '''
  CREATE TABLE stock_counts (
    id          TEXT PRIMARY KEY,
    notes       TEXT,
    created_at  TEXT NOT NULL
  )''',
  '''
  CREATE TABLE stock_count_lines (
    id                 TEXT PRIMARY KEY,
    stock_count_id     TEXT NOT NULL REFERENCES stock_counts(id),
    inventory_item_id  TEXT NOT NULL REFERENCES inventory_items(id),
    expected_milli     INTEGER NOT NULL,
    counted_milli      INTEGER NOT NULL,
    within_tolerance   INTEGER NOT NULL DEFAULT 1,
    UNIQUE (stock_count_id, inventory_item_id)
  )''',
  '''
  CREATE TABLE inventory_movements (
    id                 TEXT PRIMARY KEY,
    inventory_item_id  TEXT NOT NULL REFERENCES inventory_items(id),
    type               TEXT NOT NULL CHECK (type IN ('PURCHASE','SALE','SALE_REVERSAL','ADJUSTMENT','WASTE','INITIAL')),
    qty_milli          INTEGER NOT NULL CHECK (qty_milli <> 0),
    unit_cost_cents    INTEGER,
    order_item_id      TEXT REFERENCES order_items(id),
    purchase_item_id   TEXT REFERENCES purchase_items(id),
    stock_count_id     TEXT REFERENCES stock_counts(id),
    note               TEXT,
    created_at         TEXT NOT NULL
  )''',
  '''
  CREATE TABLE monthly_closures (
    id                        TEXT PRIMARY KEY,
    period                    TEXT NOT NULL UNIQUE,
    sales_cents               INTEGER NOT NULL,
    orders_count              INTEGER NOT NULL,
    discounts_cents           INTEGER NOT NULL,
    cash_sales_cents          INTEGER NOT NULL,
    transfer_sales_cents      INTEGER NOT NULL,
    supplies_expense_cents    INTEGER NOT NULL,
    operating_expense_cents   INTEGER NOT NULL,
    unforeseen_expense_cents  INTEGER NOT NULL,
    net_cents                 INTEGER NOT NULL,
    detail_json               TEXT NOT NULL,
    closed_at                 TEXT NOT NULL
  )''',
  '''
  CREATE TABLE audit_log (
    id            TEXT PRIMARY KEY,
    entity        TEXT NOT NULL,
    entity_id     TEXT NOT NULL,
    action        TEXT NOT NULL,
    payload_json  TEXT,
    created_at    TEXT NOT NULL
  )''',
  // Stock en caché = suma del libro mayor.
  '''
  CREATE TRIGGER trg_inventory_movement_apply
  AFTER INSERT ON inventory_movements
  BEGIN
    UPDATE inventory_items
       SET current_stock_milli = current_stock_milli + NEW.qty_milli
     WHERE id = NEW.inventory_item_id;
  END''',
  '''
  CREATE TRIGGER trg_inventory_movement_no_update
  BEFORE UPDATE ON inventory_movements
  BEGIN SELECT RAISE(ABORT, 'inventory_movements es solo-insercion'); END''',
  '''
  CREATE TRIGGER trg_inventory_movement_no_delete
  BEFORE DELETE ON inventory_movements
  BEGIN SELECT RAISE(ABORT, 'inventory_movements es solo-insercion'); END''',
  '''
  CREATE TRIGGER trg_order_items_only_open
  BEFORE INSERT ON order_items
  WHEN (SELECT status FROM orders WHERE id = NEW.order_id) <> 'OPEN'
  BEGIN SELECT RAISE(ABORT, 'Solo se pueden agregar productos a una cuenta abierta'); END''',
  'CREATE INDEX ix_orders_date ON orders(business_date, status)',
  "CREATE INDEX ix_orders_open ON orders(status) WHERE status = 'OPEN'",
  'CREATE INDEX ix_orders_shift ON orders(shift_id)',
  'CREATE INDEX ix_order_items_order ON order_items(order_id)',
  'CREATE INDEX ix_order_items_product ON order_items(product_id)',
  'CREATE INDEX ix_payments_order ON payments(order_id)',
  'CREATE INDEX ix_payments_shift ON payments(shift_id)',
  'CREATE INDEX ix_inv_mov_item ON inventory_movements(inventory_item_id, created_at)',
  'CREATE INDEX ix_expenses_date ON expenses(business_date)',
  'CREATE INDEX ix_expenses_shift ON expenses(shift_id)',
  'CREATE INDEX ix_audit_entity ON audit_log(entity, entity_id)',
];

/// Migraciones incrementales: clave = versión destino.
const migrations = <int, List<String>>{
  // 2: ['ALTER TABLE ...'],
};
