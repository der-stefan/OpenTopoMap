////////////////////////////////////////////////////////
//
// OTM Web Frontend - otm-maidenhead.js
//
// Maidenhead encoder and decoder
// based on code of Iván Sánchez Ortega 
// (https://github.com/IvanSanchez)
//
// V 2.00 - 30.04.2021 - Thomas Worbs
//          Created
//
////////////////////////////////////////////////////////

// Maidenhead decoder from qth string
// returns lat, lng, precision (2,4, or 6) or
// null if string invalid
// ===========================================
function otm_decode_maidenhead(mh_string) {
	
	// inits
	const strLen = mh_string.length;
	let minLat = -90;
	let minLng = -180;
	
	// Fields, 18x18 in total, each 20deg lng and 10deg lat
	if (mh_string.length >= 2 && mh_string.substring(0,2).match(/^[A-R]{2}$/i)) {
		minLng += 20 * getLetterIndex(mh_string.substring(0, 1));
		minLat += 10 * getLetterIndex(mh_string.substring(1, 2));
	}
	else {
		return null;
	}
	
	if (mh_string.length === 2) {
		return {lat: minLat + 5, lng: minLng + 10, zoom: 4};
	}
	
	// Squares, 10x10 per field, each 2deg lng and 1deg lat
	if (mh_string.length >= 4 && mh_string.substring(2,4).match(/^[0-9]{2}$/i)) {
		minLng += 2 * Number(mh_string.substring(2, 3));
		minLat += 1 * Number(mh_string.substring(3, 4));
	}
	else {
		return null;
	}
	
	if (mh_string.length === 4) {
		return {lat: minLat + 0.5, lng: minLng + 1, zoom: 9};
	}
	
	// Subsquares, 24x24 per square, each 5min lng and 2.5min lat
	if (mh_string.length >= 6 && mh_string.substring(4,6).match(/^[A-X]{2}$/i)) {
		minLng += (5 / 60) * getLetterIndex(mh_string.substring(4, 5));
		minLat += (2.5 / 60) * getLetterIndex(mh_string.substring(5, 6));
	}
	else {
		return null;
	}
	
	if (mh_string.length === 6) {
		return {lat: minLat + (2.5 / 60 / 2), lng: minLng + (5 / 60 / 2), zoom: 13};
	}
	
	// Extended subsquares, 10x10 per subsquare, each 0.5min lng and 0.25min lat
	if (mh_string.length >= 8 && mh_string.substring(6,8).match(/^[0-9]{2}$/i)) {
		minLng += (0.5 / 60) * Number(mh_string.substring(6, 7));
		minLat += (0.25 / 60) * Number(mh_string.substring(7, 8));
	}
	else {
		return null;
	}
	
	if (mh_string.length === 8) {
		return {lat: minLat + (0.25 / 60 / 2), lng: minLng + (0.5 / 60 / 2), zoom: 18};
	}
	
	// invalid string as no match before
	return null;
	
}

// Maidenhead encoder from lat, lng, precision (2,4,6 or 8)
// ========================================================
function otm_encode_maidenhead(lat, lng, precision) {
	
	// init return string
	let str = "";
	
	// lat-lng as percentages of the current scope
	let latPct = (lat + 90) / 180;
	while (lng > 180) {
		lng -= 360;
	}
	while (lng < -180) {
		lng += 360;
	}
	let lngPct = (lng + 180) / 360;
	
	// lat-lng will become multiples of the current scope
	
	// Fields, 18x18 in total, each 20deg lng and 10deg lat
	lngPct *= 18;
	latPct *= 18;
	str += getLetter(Math.floor(lngPct));
	str += getLetter(Math.floor(latPct));
	
	if (precision === 2) {
		return str;
	}
	
	// Squares, 10x10 per field, each 2deg lng and 1deg lat
	lngPct = (lngPct - Math.floor(lngPct)) * 10;
	latPct = (latPct - Math.floor(latPct)) * 10;
	
	str += Number(Math.floor(lngPct));
	str += Number(Math.floor(latPct));
	
	if (precision === 4) {
		return str;
	}
	
	// Subsquares, 24x24 per square, each 5min lng and 2.5min lat
	lngPct = (lngPct - Math.floor(lngPct)) * 24;
	latPct = (latPct - Math.floor(latPct)) * 24;
	
	str += getLetter(Math.floor(lngPct)).toLowerCase();
	str += getLetter(Math.floor(latPct)).toLowerCase();
	
	if (precision === 6) {
		return str;
	}
	
	// Extended subsquares, 10x10 per subsquare, each 0.5min lng and 0.25min lat
	lngPct = (lngPct - Math.floor(lngPct)) * 10;
	latPct = (latPct - Math.floor(latPct)) * 10;
	
	str += Number(Math.floor(lngPct));
	str += Number(Math.floor(latPct));
	
	if (precision === 8) {
		return str;
	}
	
	throw new Error("Precision level invalid (must be 2, 4 6 or 8)");
	}
	
	// letter index decoder
	function getLetterIndex(letter) {
		return "ABCDEFGHIJKLMNOPQRSTUVWXYZ".indexOf(letter.toUpperCase());
	};
	
	// letter index generator
	function getLetter(idx) {
		return "ABCDEFGHIJKLMNOPQRSTUVWXYZ".charAt(idx);
	};
	
	// our exports
	// ===========
	export { otm_decode_maidenhead, otm_encode_maidenhead };
	