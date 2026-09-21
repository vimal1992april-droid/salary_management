import TextField from '@mui/material/TextField'
import { useEffect, useRef, useState } from 'react'

export const SEARCH_DELAY_MS = 300

/** A search box that reports what was typed only once the user pauses, not on every keystroke. */
export default function SearchField({ value, onSearch }: { value: string; onSearch: (query: string) => void }) {
  const [text, setText] = useState(value)
  const timer = useRef<ReturnType<typeof setTimeout>>(undefined)
  const lastSent = useRef(value)

  // The URL is the source of truth. When it changes from elsewhere (for instance "Clear filters" or the browser's
  // back button), show it and drop any search still pending. Our own update coming back through the URL is ignored,
  // so it can never overwrite what the user has typed since.
  useEffect(() => {
    if (value === lastSent.current) return
    clearTimeout(timer.current)
    lastSent.current = value
    // oxlint-disable-next-line react/set-state-in-effect -- mirroring an external system (the URL) into the input
    setText(value)
  }, [value])

  useEffect(() => () => clearTimeout(timer.current), [])

  function handleChange(next: string) {
    setText(next)
    clearTimeout(timer.current)
    timer.current = setTimeout(() => {
      lastSent.current = next.trim()
      onSearch(next.trim())
    }, SEARCH_DELAY_MS)
  }

  return (
    <TextField
      type="search"
      label="Search"
      placeholder="Name, email or employee number"
      size="small"
      value={text}
      onChange={(event) => handleChange(event.target.value)}
      sx={{ minWidth: 280 }}
    />
  )
}
