const CLOSING_DAY = 25;
const OPENING_DAY = 26;

function datePartsInCairo(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  return Object.fromEntries(parts.map((part) => [part.type, part.value]));
}

function keyForDateParts(year, month, day) {
  let endYear = Number(year);
  let endMonth = Number(month);
  if (Number(day) >= OPENING_DAY) {
    endMonth += 1;
    if (endMonth === 13) {
      endMonth = 1;
      endYear += 1;
    }
  }
  return `${endYear}-${String(endMonth).padStart(2, '0')}`;
}

function cycleForKey(key) {
  const match = /^(\d{4})-(\d{2})$/.exec(String(key));
  if (!match) throw new Error(`Invalid payroll cycle key: ${key}`);
  const endYear = Number(match[1]);
  const endMonth = Number(match[2]);
  if (endMonth < 1 || endMonth > 12) {
    throw new Error(`Invalid payroll cycle key: ${key}`);
  }
  const previous = new Date(Date.UTC(endYear, endMonth - 2, 1));
  const previousYear = previous.getUTCFullYear();
  const previousMonth = previous.getUTCMonth() + 1;
  const pad = (value) => String(value).padStart(2, '0');
  return {
    key,
    startDate: `${previousYear}-${pad(previousMonth)}-${OPENING_DAY}`,
    endDate: `${endYear}-${pad(endMonth)}-${CLOSING_DAY}`,
    nextStartDate: `${endYear}-${pad(endMonth)}-${OPENING_DAY}`,
  };
}

function currentCycle(date = new Date()) {
  const parts = datePartsInCairo(date);
  return cycleForKey(keyForDateParts(parts.year, parts.month, parts.day));
}

module.exports = {
  CLOSING_DAY,
  OPENING_DAY,
  cycleForKey,
  currentCycle,
  datePartsInCairo,
  keyForDateParts,
};
