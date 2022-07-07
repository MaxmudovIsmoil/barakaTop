<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ActionModal extends Model
{
    use HasFactory;

    protected $table = 'action';

    public $timestamps = false;

    protected $fillable = [
        'name',
        'type',
        'group_id',
        'priv'
    ];

}
