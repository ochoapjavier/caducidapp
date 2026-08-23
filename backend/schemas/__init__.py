# backend/schemas/__init__.py

from .location import Location, LocationCreate
from .item import (
    StockItemCreate, StockItemCreateFromScan, StockItem, StockAlertItem,
    ProductSchema, LocationSchema,
)
from .alert import AlertResponse
from .stock_update import StockUpdate, StockRemove, StockTransferHousehold
from .product_update import ProductUpdate
from .product_actions import (
    OpenProductRequest, FreezeProductRequest, UnfreezeProductRequest,
    RelocateProductRequest, ProductActionResponse
)
from .hogar import (
    HogarCreate, HogarUpdate, HogarSchema, HogarDetalle, MiembroInfo,
    HogarMiembroCreate, HogarMiembroUpdate, HogarMiembroSchema,
    InvitacionResponse
)

from .receipt import (
    TicketMatchRequest,
    TicketParsedItem,
    TicketAllocation,
    ReceiptDictionaryEntry,
    ReceiptDictionaryProductMatch,
    SupermercadoSchema,
    SupermercadoCreate,
)

from .product_rating import (
    ProductRatingCreate,
    ProductRatingSchema,
    CatalogProductSchema,
)

__all__ = [
    "Location",
    "LocationCreate",
    "StockItemCreate",
    "StockItemCreateFromScan",
    "StockItem",
    "StockAlertItem",
    "AlertResponse",
    "StockUpdate",
    "StockRemove",
    "StockTransferHousehold",
    "ProductSchema",
    "LocationSchema",
    "ProductUpdate",
    "OpenProductRequest",
    "FreezeProductRequest",
    "UnfreezeProductRequest",
    "RelocateProductRequest",
    "ProductActionResponse",
    "HogarCreate",
    "HogarUpdate",
    "HogarSchema",
    "HogarDetalle",
    "MiembroInfo",
    "HogarMiembroCreate",
    "HogarMiembroUpdate",
    "HogarMiembroSchema",
    "InvitacionResponse",
    "TicketMatchRequest",
    "TicketParsedItem",
    "TicketAllocation",
    "ReceiptDictionaryEntry",
    "ReceiptDictionaryProductMatch",
    "SupermercadoSchema",
    "SupermercadoCreate",
    "ProductRatingCreate",
    "ProductRatingSchema",
    "CatalogProductSchema",
]

