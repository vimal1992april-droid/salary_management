/** Drops thousands separators and spaces, so "110,000" and "110 000" are accepted as typed. */
export const cleanAmount = (value: string) => value.replace(/[,\s]/g, '')

/** True for a plain number above zero, like "90000" or "90000.50" (already cleaned with cleanAmount). */
export const isPositiveAmount = (cleaned: string) => /^\d+(\.\d+)?$/.test(cleaned) && Number(cleaned) > 0
