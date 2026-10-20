// "Starts in 12 days", computed on the device at render time.
function countdown(startsAt) {
  const days = Math.ceil((new Date(startsAt) - new Date()) / 86400000);
  if (days > 1) return "Starts in " + days + " days";
  if (days === 1) return "Starts tomorrow";
  if (days === 0) return "Happening today";
  return "This event has ended";
}
