var languages = {en_gb:"English", de_de:"Deutsch"};

var en_gb = {
	language:"Language",
	garmin:"Garmin",
	about:"About",
	credits:"Credits",
	ssllink:"Use https encryption...",
	sslmore:"details",
	sslalways:"Always use https encryption",
	attribution:"map data: &copy; <a href='https://openstreetmap.org/copyright'>OpenStreetMap</a> contributors, <a href='http://viewfinderpanoramas.org'>SRTM</a> | map style: &copy; <a href='https://opentopomap.org'>OpenTopoMap</a> (<a href='https://creativecommons.org/licenses/by-sa/3.0/'>CC-BY-SA</a>)"
};

var de_de = {
	language:"Sprache",
	garmin:"Garmin",
	about:"Infos",
	credits:"Impressum",
	ssllink:"HTTPS-Verschlüsselung verwenden...",
	sslmore:"mehr Infos",
	sslalways:"zukünftig immer HTTPS verwenden",
	attribution:"Kartendaten: &copy; <a href='https://openstreetmap.org/copyright'>OpenStreetMap</a>-Mitwirkende, <a href='http://viewfinderpanoramas.org'>SRTM</a> | Kartendarstellung: &copy; <a href='https://opentopomap.org'>OpenTopoMap</a> (<a href='https://creativecommons.org/licenses/by-sa/3.0/'>CC-BY-SA</a>)"
};


var lang;
var lang_default = "en_gb"; // default language is English


function translate_detect() {
	if(lang = cookie_read('lang')) {
	} else {
		var lang_temp = window.navigator.userLanguage || window.navigator.language;
		lang = lang_temp.replace("-","_").toLowerCase();
		for(langs in languages) {
			if(langs.indexOf(lang) != -1) {
				lang=langs;
			}
		}
		document.cookie="lang="+lang+";domain=.opentopomap.org";
	}
	//lang="en_GB";

	try	{
		eval(lang);
	} catch(e) {
		lang = lang_default;
	}

}

function translate_setlang(_lang) {
	lang=_lang;
	document.getElementById("lang_list").style.backgroundImage="url('js/"+lang+".png')";
	document.cookie="lang="+lang+";domain=.opentopomap.org";
	translate_all();
}

function translate_menu() {
	var lcl = document.getElementsByClassName('leaflet-control-layers-list');

	var newSeparator = document.createElement("div");
	newSeparator.className="leaflet-control-layers-separator";
	lcl[0].insertBefore(newSeparator,lcl[0].childNodes[3]);
	
	var langdiv = document.createElement("div");
	var textp = document.createElement("span");
	textp.id="language";
	var text = document.createTextNode("Language");
	textp.appendChild(text);
	langdiv.appendChild(textp);	


	var lang_list = document.createElement("select");
	lang_list.id = "lang_list";
	lang_list.setAttribute("onchange", "translate_setlang(value)");
	langdiv.appendChild(lang_list);

	for(var langs in languages) {
		var opt = document.createElement("option"); 
		opt.text = eval(languages)[langs];
		opt.value = langs;
		opt.className = "language_element";
		opt.style.backgroundImage="url('js/"+langs+".png')";
		lang_list.className = "language_selected";
	
		if(langs == lang) {
			opt.selected=true;
			lang_list.style.backgroundImage="url('js/"+lang+".png')";
		}
		lang_list.options.add(opt);
	}

	lcl[0].insertBefore(langdiv,lcl[0].childNodes[4]);
}


function translate(elementId) {
	var element;

	if(element = document.getElementById(elementId)) {
		element.innerHTML = eval(lang)[elementId];
	}
}

function translate_leaflet(elementClass,elementName) {
	var element;
	if(element = document.getElementsByClassName(elementClass)[0]) {
		element.innerHTML = eval(lang)[elementName];
	}
}


function translate_all() {
	for(var element in eval(lang)) {
		translate(element);
	}
	
	translate_leaflet("leaflet-control-attribution","attribution");
}


function translate_init() {
	translate_detect();
	translate_menu();
	translate_all();
}
