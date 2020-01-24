{
    "views": {
        "by_date": {
            "map": "function(doc) { emit(doc['date']) }"
        },
        "by_site_code": {
            "map": "function(doc) { emit(doc['site_code']) }"
        }
    }
}