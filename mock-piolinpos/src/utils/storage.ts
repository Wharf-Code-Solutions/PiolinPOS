export const STORAGE_KEY = "piolinpos.orders.v1";
export const CHANNEL_NAME = "piolinpos-sync";

export type SyncMessage =
  | { type: "ORDER_SENT"; orderId: number }
  | { type: "ORDER_FINALIZED"; orderId: number }
  | { type: "STORE_RESET" };
