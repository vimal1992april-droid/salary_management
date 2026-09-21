import { useLocation } from 'react-router-dom'

/** Shows the router's current location, so tests can check the URL the app ended up at. */
export default function LocationSpy() {
  const location = useLocation()
  return <output data-testid="location">{`${location.pathname}${location.search}`}</output>
}
